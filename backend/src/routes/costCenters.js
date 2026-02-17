import { Router } from 'express';
import pool from '../db/pool.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireProfile } from '../middleware/requireAuth.js';
import { isGestorCentral } from '../lib/auth.js';

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
 * GET /api/cost-centers?unitId=xxx
 * Lista centros de custo. Gestor Unidade: só os vinculados a ele.
 */
router.get('/', async (req, res) => {
  try {
    const { unitId } = req.query;
    let query = `
      SELECT cc.id, cc.unit_id, cc.name, cc.created_at, cc.updated_at, u.name AS unit_name
      FROM cost_centers cc
      JOIN units u ON u.id = cc.unit_id
    `;
    const params = [];
    let idx = 1;
    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      if (ccIds.length === 0) return res.json([]);
      query += ` WHERE cc.id = ANY($${idx}::uuid[])`;
      params.push(ccIds);
      idx++;
    }
    if (unitId) {
      query += params.length ? ' AND' : ' WHERE';
      query += ` cc.unit_id = $${idx}`;
      params.push(unitId);
    }
    query += ' ORDER BY u.name, cc.name';
    const r = await pool.query(query, params);
    const list = r.rows.map((row) => ({
      id: row.id,
      unitId: row.unit_id,
      unitName: row.unit_name,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
    return res.json(list);
  } catch (err) {
    console.error('List cost centers error:', err);
    return res.status(500).json({ error: 'Erro ao listar centros de custo' });
  }
});

/**
 * POST /api/cost-centers
 * Body: { unitId, name }. Apenas Gestor Central.
 */
router.post('/', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { unitId, name } = req.body;
    if (!unitId || !name || !String(name).trim()) {
      return res.status(400).json({ error: 'unitId e name são obrigatórios' });
    }
    const insert = await pool.query(
      `INSERT INTO cost_centers (unit_id, name)
       VALUES ($1, $2)
       RETURNING id, unit_id, name, created_at, updated_at`,
      [unitId, name.trim()]
    );
    const row = insert.rows[0];
    const unitRow = await pool.query('SELECT name FROM units WHERE id = $1', [unitId]);
    return res.status(201).json({
      id: row.id,
      unitId: row.unit_id,
      unitName: unitRow.rows[0]?.name ?? null,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    if (err.code === '23503') {
      return res.status(400).json({ error: 'Unidade não encontrada' });
    }
    console.error('Create cost center error:', err);
    return res.status(500).json({ error: 'Erro ao criar centro de custo' });
  }
});

/**
 * GET /api/cost-centers/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      `SELECT cc.id, cc.unit_id, cc.name, cc.created_at, cc.updated_at, u.name AS unit_name
       FROM cost_centers cc JOIN units u ON u.id = cc.unit_id WHERE cc.id = $1`,
      [id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Centro de custo não encontrado' });
    }
    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      if (!ccIds.includes(r.rows[0].id)) {
        return res.status(404).json({ error: 'Centro de custo não encontrado' });
      }
    }
    const row = r.rows[0];
    return res.json({
      id: row.id,
      unitId: row.unit_id,
      unitName: row.unit_name,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Get cost center error:', err);
    return res.status(500).json({ error: 'Erro ao buscar centro de custo' });
  }
});

/**
 * PATCH /api/cost-centers/:id
 * Apenas Gestor Central.
 */
router.patch('/:id', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const { name, unitId } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Nome é obrigatório' });
    }
    const updates = ['name = $1', 'updated_at = NOW()'];
    const values = [name.trim()];
    let idx = 2;
    if (unitId != null) {
      updates.push(`unit_id = $${idx}`);
      values.push(unitId);
      idx++;
    }
    values.push(id);
    const r = await pool.query(
      `UPDATE cost_centers SET ${updates.join(', ')} WHERE id = $${idx}
       RETURNING id, unit_id, name, created_at, updated_at`,
      values
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Centro de custo não encontrado' });
    }
    const row = r.rows[0];
    const unitRow = await pool.query('SELECT name FROM units WHERE id = $1', [row.unit_id]);
    return res.json({
      id: row.id,
      unitId: row.unit_id,
      unitName: unitRow.rows[0]?.name ?? null,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Update cost center error:', err);
    return res.status(500).json({ error: 'Erro ao atualizar centro de custo' });
  }
});

/**
 * DELETE /api/cost-centers/:id
 * Apenas Gestor Central.
 */
router.delete('/:id', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query('DELETE FROM cost_centers WHERE id = $1 RETURNING id', [id]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Centro de custo não encontrado' });
    }
    return res.status(204).send();
  } catch (err) {
    console.error('Delete cost center error:', err);
    return res.status(500).json({ error: 'Erro ao excluir centro de custo' });
  }
});

export default router;
