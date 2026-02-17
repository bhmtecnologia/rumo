import { Router } from 'express';
import pool from '../db/pool.js';
import { logAudit } from '../lib/audit.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireProfile } from '../middleware/requireAuth.js';
import { isGestorCentral } from '../lib/auth.js';

const router = Router();

/** Lista cost_center_ids que o usuário (gestor_unidade) pode acessar */
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
 * GET /api/units
 * Lista units. Gestor Central: todas. Gestor Unidade: só units que têm ao menos um centro de custo vinculado ao usuário.
 */
router.get('/', async (req, res) => {
  try {
    let query = `
      SELECT u.id, u.name, u.created_at, u.updated_at,
             (SELECT COUNT(*) FROM cost_centers cc WHERE cc.unit_id = u.id) AS cost_center_count
      FROM units u
    `;
    const params = [];
    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      if (ccIds.length === 0) {
        return res.json([]);
      }
      query += ` WHERE EXISTS (SELECT 1 FROM cost_centers cc WHERE cc.unit_id = u.id AND cc.id = ANY($1::uuid[]))`;
      params.push(ccIds);
    }
    query += ' ORDER BY u.name';
    const r = await pool.query(query, params);
    const units = r.rows.map((row) => ({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      costCenterCount: parseInt(row.cost_center_count, 10),
    }));
    return res.json(units);
  } catch (err) {
    console.error('List units error:', err);
    return res.status(500).json({ error: 'Erro ao listar unidades' });
  }
});

/**
 * POST /api/units
 * Cria unit. Apenas Gestor Central.
 */
router.post('/', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Nome é obrigatório' });
    }
    const insert = await pool.query(
      'INSERT INTO units (name) VALUES ($1) RETURNING id, name, created_at, updated_at',
      [name.trim()]
    );
    const row = insert.rows[0];
    await logAudit('unit_created', req.user.id, 'unit', row.id, { name: row.name });
    return res.status(201).json({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Create unit error:', err);
    return res.status(500).json({ error: 'Erro ao criar unidade' });
  }
});

/**
 * GET /api/units/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query('SELECT id, name, created_at, updated_at FROM units WHERE id = $1', [
      id,
    ]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Unidade não encontrada' });
    }
    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      const ccCheck = await pool.query(
        'SELECT 1 FROM cost_centers WHERE unit_id = $1 AND id = ANY($2::uuid[]) LIMIT 1',
        [id, ccIds]
      );
      if (ccCheck.rows.length === 0) {
        return res.status(404).json({ error: 'Unidade não encontrada' });
      }
    }
    const row = r.rows[0];
    return res.json({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Get unit error:', err);
    return res.status(500).json({ error: 'Erro ao buscar unidade' });
  }
});

/**
 * PATCH /api/units/:id
 * Apenas Gestor Central.
 */
router.patch('/:id', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const { name } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Nome é obrigatório' });
    }
    const r = await pool.query(
      'UPDATE units SET name = $1, updated_at = NOW() WHERE id = $2 RETURNING id, name, created_at, updated_at',
      [name.trim(), id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Unidade não encontrada' });
    }
    const row = r.rows[0];
    await logAudit('unit_updated', req.user.id, 'unit', id, { name: row.name });
    return res.json({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Update unit error:', err);
    return res.status(500).json({ error: 'Erro ao atualizar unidade' });
  }
});

/**
 * DELETE /api/units/:id
 * Apenas Gestor Central.
 */
router.delete('/:id', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query('DELETE FROM units WHERE id = $1 RETURNING id', [id]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Unidade não encontrada' });
    }
    await logAudit('unit_deleted', req.user.id, 'unit', id, {});
    return res.status(204).send();
  } catch (err) {
    console.error('Delete unit error:', err);
    return res.status(500).json({ error: 'Erro ao excluir unidade' });
  }
});

export default router;
