import { Router } from 'express';
import pool from '../db/pool.js';
import { logAudit } from '../lib/audit.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireProfile } from '../middleware/requireAuth.js';
import { isGestorCentral } from '../lib/auth.js';
import { hashPassword } from '../lib/auth.js';

const router = Router();

async function getUserCostCenterIds(userId) {
  const r = await pool.query(
    'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
    [userId]
  );
  return r.rows.map((row) => row.cost_center_id);
}

router.use(requireAuth);
router.use(requireProfile('gestor_central', 'gestor_unidade'));

/**
 * GET /api/users
 * Lista usuários. Gestor Central: todos. Gestor Unidade: só usuários vinculados aos seus centros de custo.
 */
router.get('/', async (req, res) => {
  try {
    let query = `
      SELECT u.id, u.email, u.name, u.profile, u.created_at, u.updated_at
      FROM users u
    `;
    const params = [];
    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      if (ccIds.length === 0) return res.json([]);
      query += ` WHERE EXISTS (SELECT 1 FROM user_cost_centers ucc WHERE ucc.user_id = u.id AND ucc.cost_center_id = ANY($1::uuid[]))`;
      params.push(ccIds);
    }
    query += ' ORDER BY u.name';
    const r = await pool.query(query, params);
    const userIds = r.rows.map((row) => row.id);
    const ccRows =
      userIds.length > 0
        ? await pool.query(
            'SELECT user_id, cost_center_id FROM user_cost_centers WHERE user_id = ANY($1::uuid[])',
            [userIds]
          )
        : { rows: [] };
    const ccByUser = {};
    for (const row of ccRows.rows) {
      if (!ccByUser[row.user_id]) ccByUser[row.user_id] = [];
      ccByUser[row.user_id].push(row.cost_center_id);
    }
    const list = r.rows.map((row) => ({
      id: row.id,
      email: row.email,
      name: row.name,
      profile: row.profile,
      costCenterIds: ccByUser[row.id] ?? [],
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
    return res.json(list);
  } catch (err) {
    console.error('List users error:', err);
    return res.status(500).json({ error: 'Erro ao listar usuários' });
  }
});

/**
 * GET /api/users/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      'SELECT id, email, name, profile, created_at, updated_at FROM users WHERE id = $1',
      [id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }
    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      const ucc = await pool.query(
        'SELECT 1 FROM user_cost_centers WHERE user_id = $1 AND cost_center_id = ANY($2::uuid[]) LIMIT 1',
        [id, ccIds]
      );
      if (ucc.rows.length === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }
    }
    const row = r.rows[0];
    const ccRows = await pool.query(
      'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
      [id]
    );
    return res.json({
      id: row.id,
      email: row.email,
      name: row.name,
      profile: row.profile,
      costCenterIds: ccRows.rows.map((r) => r.cost_center_id),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Get user error:', err);
    return res.status(500).json({ error: 'Erro ao buscar usuário' });
  }
});

/**
 * PATCH /api/users/:id
 * Body: { name?, profile?, costCenterIds?, password? } (opcional). Apenas Gestor Central para alterar profile/costCenterIds.
 */
router.patch('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, profile, costCenterIds, password } = req.body;

    const isCentral = isGestorCentral(req.user);
    const isSelf = req.user.id === id;

    if (!isSelf && !isCentral) {
      return res.status(403).json({ error: 'Sem permissão para editar este usuário' });
    }

    const r = await pool.query('SELECT id FROM users WHERE id = $1', [id]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }

    const updates = [];
    const values = [];
    let idx = 1;
    if (name != null && String(name).trim()) {
      updates.push(`name = $${idx}`);
      values.push(name.trim());
      idx++;
    }
    if (profile != null && isCentral) {
      const allowed = ['gestor_central', 'gestor_unidade', 'usuario', 'motorista'];
      if (!allowed.includes(profile)) {
        return res.status(400).json({ error: 'Perfil inválido' });
      }
      updates.push(`profile = $${idx}`);
      values.push(profile);
      idx++;
    }
    if (password != null && String(password).length >= 6 && (isCentral || isSelf)) {
      const hash = await hashPassword(password);
      updates.push(`password_hash = $${idx}`);
      values.push(hash);
      idx++;
    } else if (password != null && String(password).length > 0 && String(password).length < 6) {
      return res.status(400).json({ error: 'Senha deve ter no mínimo 6 caracteres' });
    }
    if (updates.length > 0) {
      updates.push('updated_at = NOW()');
      values.push(id);
      await pool.query(
        `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx}`,
        values
      );
    }

    if (costCenterIds != null && Array.isArray(costCenterIds) && isCentral) {
      await pool.query('DELETE FROM user_cost_centers WHERE user_id = $1', [id]);
      for (const ccId of costCenterIds) {
        await pool.query(
          'INSERT INTO user_cost_centers (user_id, cost_center_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [id, ccId]
        );
      }
    }

    const updated = await pool.query(
      'SELECT id, email, name, profile, created_at, updated_at FROM users WHERE id = $1',
      [id]
    );
    const ccRows = await pool.query(
      'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
      [id]
    );
    const row = updated.rows[0];
    await logAudit('user_updated', req.user.id, 'user', id, { email: row.email });
    return res.json({
      id: row.id,
      email: row.email,
      name: row.name,
      profile: row.profile,
      costCenterIds: ccRows.rows.map((r) => r.cost_center_id),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Update user error:', err);
    return res.status(500).json({ error: 'Erro ao atualizar usuário' });
  }
});

/**
 * POST /api/users
 * Cria usuário (Gestor Central). Body: { email, password, name, profile, costCenterIds? }
 */
router.post('/', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { email, password, name, profile, costCenterIds } = req.body;
    if (!email || !password || !name || !profile) {
      return res.status(400).json({
        error: 'E-mail, senha, nome e perfil são obrigatórios',
      });
    }
    const allowed = ['gestor_central', 'gestor_unidade', 'usuario', 'motorista'];
    if (!allowed.includes(profile)) {
      return res.status(400).json({ error: 'Perfil inválido' });
    }
    if (String(password).length < 6) {
      return res.status(400).json({ error: 'Senha deve ter no mínimo 6 caracteres' });
    }
    const emailNorm = String(email).trim().toLowerCase();
    const passwordHash = await hashPassword(password);
    const insert = await pool.query(
      `INSERT INTO users (email, password_hash, name, profile)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, name, profile, created_at`,
      [emailNorm, passwordHash, name.trim(), profile]
    );
    const user = insert.rows[0];
    const costCenterIdsArr = Array.isArray(costCenterIds) ? costCenterIds : [];
    for (const ccId of costCenterIdsArr) {
      await pool.query(
        'INSERT INTO user_cost_centers (user_id, cost_center_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [user.id, ccId]
      );
    }
    const ccRows = await pool.query(
      'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
      [user.id]
    );
    await logAudit('user_created', req.user.id, 'user', user.id, { email: user.email, profile: user.profile });
    return res.status(201).json({
      id: user.id,
      email: user.email,
      name: user.name,
      profile: user.profile,
      costCenterIds: ccRows.rows.map((r) => r.cost_center_id),
      createdAt: user.created_at,
    });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Este e-mail já está cadastrado' });
    }
    console.error('Create user error:', err);
    return res.status(500).json({ error: 'Erro ao cadastrar usuário' });
  }
});

export default router;
