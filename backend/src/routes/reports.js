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

/**
 * GET /api/reports/rides
 * Query: from (ISO date), to (ISO date), costCenterId, unitId
 * Gestor Central: todas as corridas (respeitando filtros). Gestor Unidade: só corridas dos seus centros de custo.
 * Retorno JSON para exportação (CSV/XML/XLS no cliente).
 */
router.get('/rides', requireAuth, requireProfile('gestor_central', 'gestor_unidade'), async (req, res) => {
  try {
    const { from, to, costCenterId, unitId } = req.query;
    const params = [];
    let idx = 1;
    let where = '';

    if (!isGestorCentral(req.user)) {
      const ccIds = await getUserCostCenterIds(req.user.id);
      if (ccIds.length === 0) {
        return res.json([]);
      }
      where = ` WHERE r.cost_center_id = ANY($${idx}::uuid[])`;
      params.push(ccIds);
      idx++;
    }

    if (from) {
      where += (where ? ' AND' : ' WHERE') + ` r.created_at >= $${idx}::timestamptz`;
      params.push(from);
      idx++;
    }
    if (to) {
      where += (where ? ' AND' : ' WHERE') + ` r.created_at <= $${idx}::timestamptz`;
      params.push(to);
      idx++;
    }
    if (costCenterId) {
      where += (where ? ' AND' : ' WHERE') + ` r.cost_center_id = $${idx}`;
      params.push(costCenterId);
      idx++;
    }
    if (unitId) {
      where += (where ? ' AND' : ' WHERE') + ` cc.unit_id = $${idx}`;
      params.push(unitId);
      idx++;
    }

    const query = `
      SELECT
        r.id,
        r.pickup_address,
        r.pickup_lat,
        r.pickup_lng,
        r.destination_address,
        r.destination_lat,
        r.destination_lng,
        r.estimated_distance_km,
        r.estimated_duration_min,
        r.estimated_price_cents,
        r.status,
        r.created_at,
        r.accepted_at,
        r.driver_arrived_at,
        r.started_at,
        r.completed_at,
        r.cancelled_at,
        r.driver_name,
        r.vehicle_plate,
        r.actual_price_cents,
        r.actual_distance_km,
        r.actual_duration_min,
        r.rating,
        r.cancel_reason,
        r.requested_by_user_id,
        cc.id AS cost_center_id,
        cc.name AS cost_center_name,
        u.id AS unit_id,
        u.name AS unit_name,
        req.name AS requester_name,
        req.email AS requester_email
      FROM rides r
      LEFT JOIN cost_centers cc ON r.cost_center_id = cc.id
      LEFT JOIN units u ON cc.unit_id = u.id
      LEFT JOIN users req ON r.requested_by_user_id = req.id
      ${where}
      ORDER BY r.created_at DESC
      LIMIT 5000
    `;
    const r = await pool.query(query, params);
    const rows = r.rows.map((row) => ({
      id: row.id,
      pickupAddress: row.pickup_address,
      pickupLat: row.pickup_lat != null ? parseFloat(row.pickup_lat) : null,
      pickupLng: row.pickup_lng != null ? parseFloat(row.pickup_lng) : null,
      destinationAddress: row.destination_address,
      destinationLat: row.destination_lat != null ? parseFloat(row.destination_lat) : null,
      destinationLng: row.destination_lng != null ? parseFloat(row.destination_lng) : null,
      estimatedDistanceKm: row.estimated_distance_km != null ? parseFloat(row.estimated_distance_km) : null,
      estimatedDurationMin: row.estimated_duration_min ?? null,
      estimatedPriceCents: row.estimated_price_cents,
      status: row.status,
      createdAt: row.created_at,
      acceptedAt: row.accepted_at,
      driverArrivedAt: row.driver_arrived_at,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      cancelledAt: row.cancelled_at,
      driverName: row.driver_name,
      vehiclePlate: row.vehicle_plate,
      actualPriceCents: row.actual_price_cents,
      actualDistanceKm: row.actual_distance_km != null ? parseFloat(row.actual_distance_km) : null,
      actualDurationMin: row.actual_duration_min ?? null,
      rating: row.rating,
      cancelReason: row.cancel_reason,
      requestedByUserId: row.requested_by_user_id,
      costCenterId: row.cost_center_id,
      costCenterName: row.cost_center_name,
      unitId: row.unit_id,
      unitName: row.unit_name,
      requesterName: row.requester_name,
      requesterEmail: row.requester_email,
    }));
    return res.json(rows);
  } catch (err) {
    console.error('Reports rides error:', err);
    return res.status(500).json({ error: 'Erro ao gerar relatório de corridas' });
  }
});

/**
 * GET /api/reports/cadastrais
 * Query: type = units | cost_centers | users | request_reasons
 * Retorno JSON. Gestor Unidade: só units/ccs/users do seu âmbito.
 */
router.get('/cadastrais', requireAuth, requireProfile('gestor_central', 'gestor_unidade'), async (req, res) => {
  try {
    const { type } = req.query;
    if (!type || !['units', 'cost_centers', 'users', 'request_reasons'].includes(type)) {
      return res.status(400).json({ error: 'Query type deve ser: units, cost_centers, users ou request_reasons' });
    }

    const isCentral = isGestorCentral(req.user);
    let result = [];

    if (type === 'units') {
      let query = 'SELECT id, name, created_at, updated_at FROM units ORDER BY name';
      let params = [];
      if (!isCentral) {
        const ccIds = await getUserCostCenterIds(req.user.id);
        if (ccIds.length === 0) return res.json([]);
        query = `
          SELECT DISTINCT u.id, u.name, u.created_at, u.updated_at
          FROM units u
          JOIN cost_centers cc ON cc.unit_id = u.id
          WHERE cc.id = ANY($1::uuid[])
          ORDER BY u.name
        `;
        params = [ccIds];
      }
      const r = await pool.query(query, params);
      result = r.rows.map((row) => ({
        id: row.id,
        name: row.name,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    } else if (type === 'cost_centers') {
      let query = `
        SELECT cc.id, cc.unit_id, cc.name, u.name AS unit_name, cc.created_at, cc.updated_at
        FROM cost_centers cc
        JOIN units u ON u.id = cc.unit_id
        ORDER BY u.name, cc.name
      `;
      let params = [];
      if (!isCentral) {
        const ccIds = await getUserCostCenterIds(req.user.id);
        if (ccIds.length === 0) return res.json([]);
        query = `
          SELECT cc.id, cc.unit_id, cc.name, u.name AS unit_name, cc.created_at, cc.updated_at
          FROM cost_centers cc
          JOIN units u ON u.id = cc.unit_id
          WHERE cc.id = ANY($1::uuid[])
          ORDER BY u.name, cc.name
        `;
        params = [ccIds];
      }
      const r = await pool.query(query, params);
      result = r.rows.map((row) => ({
        id: row.id,
        unitId: row.unit_id,
        name: row.name,
        unitName: row.unit_name,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    } else if (type === 'users') {
      let query = `
        SELECT u.id, u.email, u.name, u.profile, u.created_at, u.updated_at
        FROM users u
        ORDER BY u.name
      `;
      let params = [];
      if (!isCentral) {
        const ccIds = await getUserCostCenterIds(req.user.id);
        if (ccIds.length === 0) return res.json([]);
        query = `
          SELECT DISTINCT u.id, u.email, u.name, u.profile, u.created_at, u.updated_at
          FROM users u
          JOIN user_cost_centers ucc ON ucc.user_id = u.id
          WHERE ucc.cost_center_id = ANY($1::uuid[])
          ORDER BY u.name
        `;
        params = [ccIds];
      }
      const r = await pool.query(query, params);
      result = r.rows.map((row) => ({
        id: row.id,
        email: row.email,
        name: row.name,
        profile: row.profile,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    } else if (type === 'request_reasons') {
      const r = await pool.query(
        'SELECT id, name, created_at, updated_at FROM request_reasons ORDER BY name'
      );
      result = r.rows.map((row) => ({
        id: row.id,
        name: row.name,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    }

    return res.json(result);
  } catch (err) {
    console.error('Reports cadastrais error:', err);
    return res.status(500).json({ error: 'Erro ao gerar relatório cadastral' });
  }
});

export default router;
