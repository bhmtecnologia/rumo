import { Router } from 'express';
import pool from '../db/pool.js';
import { logAudit } from '../lib/audit.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireProfile } from '../middleware/requireAuth.js';
import { isGestorCentral } from '../lib/auth.js';

const router = Router();

function mapCostCenterRow(row) {
  const base = {
    id: row.id,
    unitId: row.unit_id,
    unitName: row.unit_name,
    name: row.name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
  if (row.blocked != null) base.blocked = row.blocked;
  if (row.monthly_limit_cents != null) base.monthlyLimitCents = row.monthly_limit_cents;
  if (row.max_km != null) base.maxKm = parseFloat(row.max_km);
  if (row.allowed_time_start != null) base.allowedTimeStart = row.allowed_time_start;
  if (row.allowed_time_end != null) base.allowedTimeEnd = row.allowed_time_end;
  return base;
}

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
      SELECT cc.id, cc.unit_id, cc.name, cc.created_at, cc.updated_at, u.name AS unit_name,
             cc.blocked, cc.monthly_limit_cents, cc.max_km, cc.allowed_time_start, cc.allowed_time_end
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
    const list = r.rows.map((row) => mapCostCenterRow(row));
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
    await logAudit('cost_center_created', req.user.id, 'cost_center', row.id, { name: row.name, unitId });
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
      `SELECT cc.id, cc.unit_id, cc.name, cc.created_at, cc.updated_at, u.name AS unit_name,
              cc.blocked, cc.monthly_limit_cents, cc.max_km, cc.allowed_time_start, cc.allowed_time_end
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
    const out = mapCostCenterRow(row);
    const areas = await pool.query(
      'SELECT id, type, lat, lng, radius_km, label FROM cost_center_allowed_areas WHERE cost_center_id = $1',
      [id]
    );
    out.allowedAreas = areas.rows.map((a) => ({
      id: a.id,
      type: a.type,
      lat: parseFloat(a.lat),
      lng: parseFloat(a.lng),
      radiusKm: parseFloat(a.radius_km),
      label: a.label,
    }));
    return res.json(out);
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
    const {
      name,
      unitId,
      blocked,
      monthlyLimitCents,
      maxKm,
      allowedTimeStart,
      allowedTimeEnd,
    } = req.body;
    const updates = ['updated_at = NOW()'];
    const values = [];
    let idx = 1;
    if (name != null && String(name).trim()) {
      updates.push(`name = $${idx}`);
      values.push(name.trim());
      idx++;
    }
    if (unitId != null) {
      updates.push(`unit_id = $${idx}`);
      values.push(unitId);
      idx++;
    }
    if (blocked !== undefined) {
      updates.push(`blocked = $${idx}`);
      values.push(!!blocked);
      idx++;
    }
    if (monthlyLimitCents !== undefined) {
      updates.push(`monthly_limit_cents = $${idx}`);
      values.push(monthlyLimitCents === null ? null : parseInt(monthlyLimitCents, 10));
      idx++;
    }
    if (maxKm !== undefined) {
      updates.push(`max_km = $${idx}`);
      values.push(maxKm === null ? null : parseFloat(maxKm));
      idx++;
    }
    if (allowedTimeStart !== undefined) {
      updates.push(`allowed_time_start = $${idx}`);
      values.push(allowedTimeStart === null || allowedTimeStart === '' ? null : allowedTimeStart);
      idx++;
    }
    if (allowedTimeEnd !== undefined) {
      updates.push(`allowed_time_end = $${idx}`);
      values.push(allowedTimeEnd === null || allowedTimeEnd === '' ? null : allowedTimeEnd);
      idx++;
    }
    if (values.length === 0) {
      return res.status(400).json({ error: 'Nenhum campo para atualizar' });
    }
    values.push(id);
    const r = await pool.query(
      `UPDATE cost_centers SET ${updates.join(', ')} WHERE id = $${idx}
       RETURNING id, unit_id, name, created_at, updated_at, blocked, monthly_limit_cents, max_km, allowed_time_start, allowed_time_end`,
      values
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Centro de custo não encontrado' });
    }
    const row = r.rows[0];
    const unitRow = await pool.query('SELECT name FROM units WHERE id = $1', [row.unit_id]);
    const out = mapCostCenterRow({ ...row, unit_name: unitRow.rows[0]?.name });
    await logAudit('cost_center_updated', req.user.id, 'cost_center', id, { name: row.name });
    return res.json(out);
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
    await logAudit('cost_center_deleted', req.user.id, 'cost_center', id, {});
    return res.status(204).send();
  } catch (err) {
    console.error('Delete cost center error:', err);
    return res.status(500).json({ error: 'Erro ao excluir centro de custo' });
  }
});

/**
 * POST /api/cost-centers/:id/areas
 * Body: { type: 'origin'|'destination', lat, lng, radiusKm, label? }. Apenas Gestor Central.
 */
router.post('/:id/areas', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const { type, lat, lng, radiusKm, label } = req.body;
    if (!type || !['origin', 'destination'].includes(type) || lat == null || lng == null) {
      return res.status(400).json({
        error: 'type (origin ou destination), lat e lng são obrigatórios',
      });
    }
    const radius = radiusKm != null ? parseFloat(radiusKm) : 5;
    const insert = await pool.query(
      `INSERT INTO cost_center_allowed_areas (cost_center_id, type, lat, lng, radius_km, label)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, type, lat, lng, radius_km, label`,
      [id, type, parseFloat(lat), parseFloat(lng), radius, label?.trim() || null]
    );
    const row = insert.rows[0];
    return res.status(201).json({
      id: row.id,
      type: row.type,
      lat: parseFloat(row.lat),
      lng: parseFloat(row.lng),
      radiusKm: parseFloat(row.radius_km),
      label: row.label,
    });
  } catch (err) {
    if (err.code === '23503') {
      return res.status(404).json({ error: 'Centro de custo não encontrado' });
    }
    console.error('Create area error:', err);
    return res.status(500).json({ error: 'Erro ao criar área' });
  }
});

/**
 * DELETE /api/cost-centers/:id/areas/:areaId
 * Apenas Gestor Central.
 */
router.delete('/:id/areas/:areaId', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id, areaId } = req.params;
    const r = await pool.query(
      'DELETE FROM cost_center_allowed_areas WHERE id = $1 AND cost_center_id = $2 RETURNING id',
      [areaId, id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Área não encontrada' });
    }
    return res.status(204).send();
  } catch (err) {
    console.error('Delete area error:', err);
    return res.status(500).json({ error: 'Erro ao excluir área' });
  }
});

export default router;
