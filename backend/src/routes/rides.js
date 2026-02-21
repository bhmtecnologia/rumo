import { Router } from 'express';
import pool from '../db/pool.js';
import { getSupabase, useSupabase } from '../db/supabase.js';
import { calculateFare, getDistanceAndDuration } from '../lib/fare.js';
import { isGestorCentral, isGestorUnidade, isMotorista } from '../lib/auth.js';
import { checkRestrictions } from '../lib/restrictions.js';
import { logAudit } from '../lib/audit.js';
import { sendNewRideNotificationToDrivers, sendDriverAcceptedNotificationToPassenger } from '../lib/push.js';

const router = Router();

async function getOnlineDriverFcmTokens() {
  if (useSupabase()) {
    const { data: online } = await getSupabase()
      .from('driver_availability')
      .select('user_id')
      .eq('is_online', true);
    const userIds = (online || []).map((r) => r.user_id);
    if (userIds.length === 0) return [];
    const { data: rows } = await getSupabase()
      .from('driver_fcm_tokens')
      .select('token')
      .in('user_id', userIds);
    return (rows || []).map((r) => r.token).filter(Boolean);
  }
  const r = await pool.query(
    `SELECT t.token FROM driver_fcm_tokens t
     JOIN driver_availability d ON d.user_id = t.user_id
     WHERE d.is_online = true`
  );
  return r.rows.map((row) => row.token).filter(Boolean);
}

function mapRideRow(row) {
  const base = {
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
    updatedAt: row.updated_at,
    formattedPrice: ((Number(row.estimated_price_cents) || 0) / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }),
  };
  if (row.driver_user_id != null) base.driverUserId = row.driver_user_id;
  if (row.driver_name != null) base.driverName = row.driver_name;
  if (row.vehicle_plate != null) base.vehiclePlate = row.vehicle_plate;
  if (row.accepted_at != null) base.acceptedAt = row.accepted_at;
  if (row.driver_arrived_at != null) base.driverArrivedAt = row.driver_arrived_at;
  if (row.started_at != null) base.startedAt = row.started_at;
  if (row.completed_at != null) base.completedAt = row.completed_at;
  if (row.cancelled_at != null) base.cancelledAt = row.cancelled_at;
  if (row.actual_price_cents != null) base.actualPriceCents = row.actual_price_cents;
  if (row.actual_distance_km != null) base.actualDistanceKm = parseFloat(row.actual_distance_km);
  if (row.actual_duration_min != null) base.actualDurationMin = row.actual_duration_min;
  if (row.rating != null) base.rating = row.rating;
  if (row.cancel_reason != null) base.cancelReason = row.cancel_reason;
  if (row.requested_by_user_id != null) base.requestedByUserId = row.requested_by_user_id;
  if (row.trajectory != null) base.trajectory = row.trajectory;
  return base;
}

async function getFareConfig() {
  if (useSupabase()) {
    const { data } = await getSupabase()
      .from('fare_config')
      .select('base_fare_cents, per_km_cents, per_minute_cents, min_fare_cents')
      .limit(1)
      .maybeSingle();
    return data ?? null;
  }
  const r = await pool.query(
    'SELECT base_fare_cents, per_km_cents, per_minute_cents, min_fare_cents FROM fare_config LIMIT 1'
  );
  return r.rows[0] || null;
}

async function getUserCostCenterIds(userId) {
  if (useSupabase()) {
    const { data } = await getSupabase()
      .from('user_cost_centers')
      .select('cost_center_id')
      .eq('user_id', userId);
    return (data || []).map((row) => row.cost_center_id);
  }
  const r = await pool.query(
    'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
    [userId]
  );
  return r.rows.map((row) => row.cost_center_id);
}

async function resolveCostCenterForRequest(userId, bodyCostCenterId) {
  const ccIds = await getUserCostCenterIds(userId);
  if (ccIds.length === 0) return { costCenterId: null, error: null };
  if (bodyCostCenterId) {
    if (!ccIds.includes(bodyCostCenterId)) {
      return { costCenterId: null, error: 'Centro de custo não vinculado ao usuário.' };
    }
    return { costCenterId: bodyCostCenterId, error: null };
  }
  if (ccIds.length === 1) return { costCenterId: ccIds[0], error: null };
  return { costCenterId: null, error: 'Informe o centro de custo para esta solicitação.' };
}

/**
 * POST /api/estimate
 * Body: { pickupAddress, pickupLat, pickupLng, destinationAddress, destinationLat, destinationLng }
 * Retorna: { distanceKm, durationMin, estimatedPriceCents, formattedPrice }
 */
router.post('/estimate', async (req, res) => {
  try {
    const {
      pickupAddress,
      pickupLat,
      pickupLng,
      destinationAddress,
      destinationLat,
      destinationLng,
    } = req.body;

    if (!pickupAddress || !destinationAddress) {
      return res.status(400).json({
        error: 'pickupAddress e destinationAddress são obrigatórios',
      });
    }

    const hasCoords =
      pickupLat != null &&
      pickupLng != null &&
      destinationLat != null &&
      destinationLng != null;

    let distanceKm = 5;
    let durationMin = 12;
    if (hasCoords) {
      const result = getDistanceAndDuration(
        pickupLat,
        pickupLng,
        destinationLat,
        destinationLng
      );
      distanceKm = Math.round(result.distanceKm * 100) / 100;
      durationMin = result.durationMin;
    }

    let config = null;
    try {
      config = await getFareConfig();
    } catch (dbErr) {
      console.error('getFareConfig error:', dbErr);
    }
    const estimatedPriceCents = calculateFare(distanceKm, durationMin, config);
    const formattedPrice = (estimatedPriceCents / 100).toLocaleString('pt-BR', {
      style: 'currency',
      currency: 'BRL',
    });

    const userId = req.user?.id;
    if (userId) {
      const { costCenterId, error: resolveErr } = await resolveCostCenterForRequest(
        userId,
        req.body.cost_center_id
      );
      if (resolveErr) {
        return res.status(400).json({ error: resolveErr });
      }
      if (costCenterId) {
        const check = await checkRestrictions(costCenterId, userId, {
          pickupLat,
          pickupLng,
          destinationLat,
          destinationLng,
          estimatedPriceCents,
          estimatedDistanceKm,
        });
        if (!check.allowed) {
          return res.status(403).json({ error: check.error });
        }
      }
    }

    return res.json({
      distanceKm,
      durationMin,
      estimatedPriceCents,
      formattedPrice,
    });
  } catch (err) {
    console.error('Estimate error:', err);
    return res.status(500).json({ error: 'Erro ao calcular estimativa' });
  }
});

/**
 * POST /api/rides
 * Cria uma corrida (request).
 */
router.post('/', async (req, res) => {
  try {
    const {
      pickupAddress,
      pickupLat,
      pickupLng,
      destinationAddress,
      destinationLat,
      destinationLng,
      estimatedPriceCents,
      estimatedDistanceKm,
      estimatedDurationMin,
      cost_center_id: bodyCostCenterId,
    } = req.body;

    if (!pickupAddress || !destinationAddress || estimatedPriceCents == null) {
      return res.status(400).json({
        error: 'pickupAddress, destinationAddress e estimatedPriceCents são obrigatórios',
      });
    }

    const userId = req.user?.id ?? null;
    const { costCenterId, error: resolveErr } = await resolveCostCenterForRequest(userId, bodyCostCenterId);
    if (resolveErr) {
      return res.status(400).json({ error: resolveErr });
    }

    let distanceKm = estimatedDistanceKm ?? 5;
    let durationMin = estimatedDurationMin ?? 12;
    if (
      pickupLat != null &&
      pickupLng != null &&
      destinationLat != null &&
      destinationLng != null
    ) {
      const result = getDistanceAndDuration(
        pickupLat,
        pickupLng,
        destinationLat,
        destinationLng
      );
      distanceKm = Math.round(result.distanceKm * 100) / 100;
      durationMin = result.durationMin;
    }

    const price = estimatedPriceCents ?? calculateFare(distanceKm, durationMin, await getFareConfig());

    if (costCenterId) {
      const check = await checkRestrictions(costCenterId, userId, {
        pickupLat: pickupLat ?? null,
        pickupLng: pickupLng ?? null,
        destinationLat: destinationLat ?? null,
        destinationLng: destinationLng ?? null,
        estimatedPriceCents: price,
        estimatedDistanceKm: distanceKm,
      });
      if (!check.allowed) {
        return res.status(403).json({ error: check.error });
      }
    }

    let ride = null;
    if (useSupabase()) {
      const { data, error } = await getSupabase()
        .from('rides')
        .insert({
          pickup_address: pickupAddress,
          pickup_lat: pickupLat ?? null,
          pickup_lng: pickupLng ?? null,
          destination_address: destinationAddress,
          destination_lat: destinationLat ?? null,
          destination_lng: destinationLng ?? null,
          estimated_distance_km: distanceKm,
          estimated_duration_min: durationMin,
          estimated_price_cents: price,
          status: 'requested',
          requested_by_user_id: userId,
          cost_center_id: costCenterId ?? null,
        })
        .select('id, pickup_address, destination_address, estimated_price_cents, estimated_distance_km, estimated_duration_min, status, created_at')
        .single();
      if (error) {
        console.error('Create ride supabase error:', error);
        throw error;
      }
      ride = data;
    } else {
      const insert = await pool.query(
        `INSERT INTO rides (
          pickup_address, pickup_lat, pickup_lng,
          destination_address, destination_lat, destination_lng,
          estimated_distance_km, estimated_duration_min, estimated_price_cents,
          status, requested_by_user_id, cost_center_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'requested', $10, $11)
        RETURNING id, pickup_address, destination_address, estimated_price_cents,
                  estimated_distance_km, estimated_duration_min, status, created_at`,
        [
          pickupAddress,
          pickupLat ?? null,
          pickupLng ?? null,
          destinationAddress,
          destinationLat ?? null,
          destinationLng ?? null,
          distanceKm,
          durationMin,
          price,
          userId,
          costCenterId ?? null,
        ]
      );
      ride = insert.rows[0];
    }
    const formattedPrice = (ride.estimated_price_cents / 100).toLocaleString(
      'pt-BR',
      { style: 'currency', currency: 'BRL' }
    );

    // Push para motoristas online
    try {
      const tokens = await getOnlineDriverFcmTokens();
      console.log('[push] Nova corrida', ride.id, '→', tokens.length, 'token(s) de motoristas online');
      if (tokens.length > 0) {
        await sendNewRideNotificationToDrivers(tokens, {
          id: ride.id,
          pickupAddress: ride.pickup_address,
          destinationAddress: ride.destination_address,
          formattedPrice,
        });
      }
    } catch (pushErr) {
      console.error('Push new ride error:', pushErr);
    }

    return res.status(201).json({
      id: ride.id,
      status: ride.status,
      pickupAddress: ride.pickup_address,
      destinationAddress: ride.destination_address,
      estimatedPriceCents: ride.estimated_price_cents,
      formattedPrice,
    });
  } catch (err) {
    console.error('Create ride error:', err);
    return res.status(500).json({ error: 'Erro ao solicitar corrida' });
  }
});

const RIDE_LIST_COLS = `
  id, pickup_address, pickup_lat, pickup_lng,
  destination_address, destination_lat, destination_lng,
  estimated_distance_km, estimated_duration_min, estimated_price_cents,
  status, created_at, driver_user_id, driver_name, vehicle_plate,
  accepted_at, driver_arrived_at, started_at, completed_at, cancelled_at,
  requested_by_user_id
`;

/**
 * GET /api/rides?available=1
 * Lista corridas. Gestor Central e Gestor Unidade: todas (central). Motorista: ?available=1 = status requested; senão = minhas (que dirijo OU que solicitei). Outros: só as que solicitei.
 */
router.get('/', async (req, res) => {
  try {
    const user = req.user;
    const isCentral = user && isGestorCentral(user);
    const isUnidade = user && isGestorUnidade(user);
    const isDriver = user && isMotorista(user);

    if (useSupabase()) {
      const supabase = getSupabase();
      let q = supabase.from('rides').select('*').order('created_at', { ascending: false });
      if (isCentral || isUnidade) {
        q = q.limit(100);
      } else if (isDriver && req.query.available === '1') {
        q = q.eq('status', 'requested').limit(50);
      } else if (isDriver) {
        q = q.or(`driver_user_id.eq."${user.id}",requested_by_user_id.eq."${user.id}"`).limit(100);
      } else {
        q = q.eq('requested_by_user_id', user.id).limit(100);
      }
      const { data: rows, error } = await q;
      if (error) {
        console.error('List rides Supabase error:', error.message || error, error);
        return res.status(500).json({ error: 'Erro ao listar corridas' });
      }
      const rides = (rows || []).map((row) => mapRideRow(row));
      return res.json(rides);
    }

    let query;
    let params = [];
    if (isCentral || isUnidade) {
      query = `SELECT ${RIDE_LIST_COLS} FROM rides ORDER BY created_at DESC LIMIT 100`;
    } else if (isDriver && req.query.available === '1') {
      query = `SELECT ${RIDE_LIST_COLS} FROM rides WHERE status = 'requested' ORDER BY created_at DESC LIMIT 50`;
    } else if (isDriver) {
      query = `SELECT ${RIDE_LIST_COLS} FROM rides WHERE driver_user_id = $1 OR requested_by_user_id = $1 ORDER BY created_at DESC LIMIT 100`;
      params = [user.id, user.id];
    } else {
      query = `SELECT ${RIDE_LIST_COLS} FROM rides WHERE requested_by_user_id = $1 ORDER BY created_at DESC LIMIT 100`;
      params = [user.id];
    }
    const r = await pool.query(query, params);
    const rides = r.rows.map((row) => mapRideRow(row));
    return res.json(rides);
  } catch (err) {
    console.error('List rides error:', err);
    return res.status(500).json({ error: 'Erro ao listar corridas' });
  }
});

/**
 * PATCH /api/rides/:id/accept — Motorista aceita. Body: { vehiclePlate? }
 */
router.patch('/:id/accept', async (req, res) => {
  try {
    if (!isMotorista(req.user)) {
      return res.status(403).json({ error: 'Apenas motoristas podem aceitar corridas.' });
    }
    const { id } = req.params;
    const vehiclePlate = req.body?.vehiclePlate?.trim() || null;
    const userId = req.user.id;
    const userName = req.user.name;

    if (useSupabase()) {
      const { data: existing, error: fetchErr } = await getSupabase()
        .from('rides')
        .select('id, status')
        .eq('id', id)
        .single();
      if (fetchErr || !existing) {
        return res.status(404).json({ error: 'Corrida não encontrada ou já foi aceita.' });
      }
      if (existing.status !== 'requested') {
        return res.status(404).json({ error: 'Corrida já foi aceita por outro motorista.' });
      }
      const { data: updated, error: updateErr } = await getSupabase()
        .from('rides')
        .update({
          status: 'accepted',
          driver_user_id: userId,
          driver_name: userName,
          vehicle_plate: vehiclePlate,
          accepted_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)
        .eq('status', 'requested')
        .select()
        .single();
      if (updateErr || !updated) {
        return res.status(404).json({ error: 'Corrida não encontrada ou já foi aceita.' });
      }
      await logAudit('ride_accepted', userId, 'ride', id, { vehiclePlate });
      const requesterId = updated.requested_by_user_id;
      if (requesterId) {
        const { data: pt } = await getSupabase()
          .from('passenger_fcm_tokens')
          .select('token')
          .eq('user_id', requesterId);
        const passengerTokens = (pt || []).map((r) => r.token).filter(Boolean);
        if (passengerTokens.length > 0) {
          sendDriverAcceptedNotificationToPassenger(passengerTokens, {
            id: updated.id,
            driverName: userName,
            vehiclePlate,
          });
        }
      }
      return res.json(mapRideRow(updated));
    }

    const r = await pool.query(
      `UPDATE rides SET status = 'accepted', driver_user_id = $1, driver_name = $2, vehicle_plate = $3, accepted_at = NOW(), updated_at = NOW()
       WHERE id = $4 AND status = 'requested' RETURNING *`,
      [userId, userName, vehiclePlate, id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada ou já foi aceita.' });
    }
    await logAudit('ride_accepted', userId, 'ride', id, { vehiclePlate });
    const row = r.rows[0];
    const requesterId = row.requested_by_user_id;
    if (requesterId) {
      const tr = await pool.query('SELECT token FROM passenger_fcm_tokens WHERE user_id = $1', [requesterId]);
      const passengerTokens = tr.rows.map((r) => r.token).filter(Boolean);
      if (passengerTokens.length > 0) {
        sendDriverAcceptedNotificationToPassenger(passengerTokens, {
          id: row.id,
          driverName: userName,
          vehiclePlate,
        });
      }
    }
    return res.json(mapRideRow(row));
  } catch (err) {
    console.error('Accept ride error:', err);
    return res.status(500).json({ error: 'Erro ao aceitar corrida' });
  }
});

/**
 * PATCH /api/rides/:id/arrived — Motorista chegou na origem
 */
router.patch('/:id/arrived', async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    if (useSupabase()) {
      const { data: existing, error: fetchErr } = await getSupabase()
        .from('rides')
        .select('id, status, driver_user_id')
        .eq('id', id)
        .single();
      if (fetchErr || !existing) {
        return res.status(404).json({ error: 'Corrida não encontrada ou você não é o motorista.' });
      }
      if (existing.driver_user_id !== userId || existing.status !== 'accepted') {
        return res.status(404).json({ error: 'Corrida não encontrada ou status inválido.' });
      }
      const { data: updated, error: updateErr } = await getSupabase()
        .from('rides')
        .update({
          status: 'driver_arrived',
          driver_arrived_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', id)
        .eq('driver_user_id', userId)
        .eq('status', 'accepted')
        .select()
        .single();
      if (updateErr || !updated) {
        return res.status(404).json({ error: 'Corrida não encontrada ou status inválido.' });
      }
      await logAudit('ride_driver_arrived', userId, 'ride', id, {});
      return res.json(mapRideRow(updated));
    }

    const r = await pool.query(
      `UPDATE rides SET status = 'driver_arrived', driver_arrived_at = NOW(), updated_at = NOW()
       WHERE id = $1 AND driver_user_id = $2 AND status = 'accepted' RETURNING *`,
      [id, userId]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada ou você não é o motorista.' });
    }
    await logAudit('ride_driver_arrived', req.user.id, 'ride', id, {});
    return res.json(mapRideRow(r.rows[0]));
  } catch (err) {
    console.error('Arrived error:', err);
    return res.status(500).json({ error: 'Erro ao registrar chegada' });
  }
});

/**
 * PATCH /api/rides/:id/start — Iniciar viagem
 */
router.patch('/:id/start', async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      `UPDATE rides SET status = 'in_progress', started_at = NOW(), updated_at = NOW()
       WHERE id = $1 AND driver_user_id = $2 AND status = 'driver_arrived' RETURNING *`,
      [id, req.user.id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada ou status inválido.' });
    }
    await logAudit('ride_started', req.user.id, 'ride', id, {});
    return res.json(mapRideRow(r.rows[0]));
  } catch (err) {
    console.error('Start ride error:', err);
    return res.status(500).json({ error: 'Erro ao iniciar corrida' });
  }
});

/**
 * PATCH /api/rides/:id/complete — Finalizar viagem. Body: { actualPriceCents, actualDistanceKm?, actualDurationMin? }
 */
router.patch('/:id/complete', async (req, res) => {
  try {
    const { id } = req.params;
    const { actualPriceCents, actualDistanceKm, actualDurationMin } = req.body;
    if (actualPriceCents == null) {
      return res.status(400).json({ error: 'actualPriceCents é obrigatório.' });
    }
    const r = await pool.query(
      `UPDATE rides SET status = 'completed', completed_at = NOW(), updated_at = NOW(),
        actual_price_cents = $1, actual_distance_km = $2, actual_duration_min = $3
       WHERE id = $4 AND driver_user_id = $5 AND status = 'in_progress' RETURNING *`,
      [actualPriceCents, actualDistanceKm ?? null, actualDurationMin ?? null, id, req.user.id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada ou status inválido.' });
    }
    await logAudit('ride_completed', req.user.id, 'ride', id, { actualPriceCents, actualDistanceKm, actualDurationMin });
    return res.json(mapRideRow(r.rows[0]));
  } catch (err) {
    console.error('Complete ride error:', err);
    return res.status(500).json({ error: 'Erro ao finalizar corrida' });
  }
});

/**
 * PATCH /api/rides/:id/cancel — Cancelar (solicitante, motorista ou gestor central/unidade). Body: { reason? }
 */
router.patch('/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    const reason = req.body?.reason?.trim() || null;
    let row;

    if (useSupabase()) {
      const { data, error } = await getSupabase().from('rides').select('id, requested_by_user_id, driver_user_id, status').eq('id', id).single();
      if (error || !data) {
        return res.status(404).json({ error: 'Corrida não encontrada.' });
      }
      row = data;
    } else {
      const r = await pool.query(
        `SELECT id, requested_by_user_id, driver_user_id, status FROM rides WHERE id = $1`,
        [id]
      );
      if (r.rows.length === 0) {
        return res.status(404).json({ error: 'Corrida não encontrada.' });
      }
      row = r.rows[0];
    }

    const isCentral = isGestorCentral(req.user);
    const isUnidade = isGestorUnidade(req.user);
    const isRequester = row.requested_by_user_id === req.user.id;
    const isDriver = row.driver_user_id === req.user.id;
    if (!isCentral && !isUnidade && !isRequester && !isDriver) {
      return res.status(403).json({ error: 'Apenas solicitante, motorista ou gestor podem cancelar.' });
    }
    const finalStatuses = ['completed', 'cancelled'];
    if (finalStatuses.includes(row.status)) {
      return res.status(400).json({ error: 'Corrida já finalizada ou cancelada.' });
    }

    if (useSupabase()) {
      const { error: updateError } = await getSupabase()
        .from('rides')
        .update({
          status: 'cancelled',
          cancelled_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          cancel_reason: reason,
          cancelled_by_user_id: req.user.id,
        })
        .eq('id', id);
      if (updateError) {
        console.error('Cancel ride Supabase error:', updateError);
        return res.status(500).json({ error: 'Erro ao cancelar corrida' });
      }
      const { data: updated } = await getSupabase().from('rides').select('*').eq('id', id).single();
      await logAudit('ride_cancelled', req.user.id, 'ride', id, { reason });
      return res.json(mapRideRow(updated));
    }

    await pool.query(
      `UPDATE rides SET status = 'cancelled', cancelled_at = NOW(), updated_at = NOW(),
        cancel_reason = $1, cancelled_by_user_id = $2
       WHERE id = $3`,
      [reason, req.user.id, id]
    );
    await logAudit('ride_cancelled', req.user.id, 'ride', id, { reason });
    const updated = await pool.query('SELECT * FROM rides WHERE id = $1', [id]);
    return res.json(mapRideRow(updated.rows[0]));
  } catch (err) {
    console.error('Cancel ride error:', err);
    return res.status(500).json({ error: 'Erro ao cancelar corrida' });
  }
});

/**
 * POST /api/rides/:id/rate — Avaliar (1-5). Apenas solicitante, corrida completed.
 */
router.post('/:id/rate', async (req, res) => {
  try {
    const { id } = req.params;
    const rating = req.body?.rating != null ? Number(req.body.rating) : null;
    if (rating == null || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'rating deve ser entre 1 e 5.' });
    }
    const r = await pool.query(
      `UPDATE rides SET rating = $1, updated_at = NOW()
       WHERE id = $2 AND requested_by_user_id = $3 AND status = 'completed' RETURNING *`,
      [Math.floor(rating), id, req.user.id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada ou já avaliada.' });
    }
    return res.json(mapRideRow(r.rows[0]));
  } catch (err) {
    console.error('Rate ride error:', err);
    return res.status(500).json({ error: 'Erro ao avaliar' });
  }
});

/**
 * GET /api/rides/:id/receipt — Recibo da corrida (apenas corridas finalizadas; acesso: solicitante, motorista ou gestor central)
 */
router.get('/:id/receipt', async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      `SELECT * FROM rides WHERE id = $1`,
      [id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada' });
    }
    const row = r.rows[0];
    if (row.status !== 'completed') {
      return res.status(400).json({ error: 'Recibo disponível apenas para corridas finalizadas.' });
    }
    const isCentral = isGestorCentral(req.user);
    const isRequester = row.requested_by_user_id === req.user.id;
    const isDriver = row.driver_user_id === req.user.id;
    if (!isCentral && !isRequester && !isDriver) {
      return res.status(403).json({ error: 'Acesso negado a esta corrida.' });
    }
    const receipt = {
      id: row.id,
      pickupAddress: row.pickup_address,
      destinationAddress: row.destination_address,
      driverName: row.driver_name,
      vehiclePlate: row.vehicle_plate,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      actualPriceCents: row.actual_price_cents,
      formattedPrice: (row.actual_price_cents / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }),
      actualDistanceKm: row.actual_distance_km != null ? parseFloat(row.actual_distance_km) : null,
      actualDurationMin: row.actual_duration_min ?? null,
      rating: row.rating,
    };
    return res.json(receipt);
  } catch (err) {
    console.error('Get receipt error:', err);
    return res.status(500).json({ error: 'Erro ao buscar recibo' });
  }
});

/**
 * GET /api/rides/:id/messages — Lista mensagens da corrida (solicitante, motorista ou gestor central)
 */
router.get('/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const ride = await pool.query('SELECT requested_by_user_id, driver_user_id FROM rides WHERE id = $1', [id]);
    if (ride.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada' });
    }
    const { requested_by_user_id, driver_user_id } = ride.rows[0];
    const isCentral = isGestorCentral(req.user);
    const isRequester = requested_by_user_id === req.user.id;
    const isDriver = driver_user_id === req.user.id;
    if (!isCentral && !isRequester && !isDriver) {
      return res.status(403).json({ error: 'Acesso negado a esta corrida.' });
    }
    const r = await pool.query(
      `SELECT rm.id, rm.ride_id, rm.user_id, u.name AS user_name, rm.text, rm.created_at
       FROM ride_messages rm
       JOIN users u ON u.id = rm.user_id
       WHERE rm.ride_id = $1
       ORDER BY rm.created_at ASC`,
      [id]
    );
    const messages = r.rows.map((row) => ({
      id: row.id,
      rideId: row.ride_id,
      userId: row.user_id,
      userName: row.user_name,
      text: row.text,
      createdAt: row.created_at,
    }));
    return res.json(messages);
  } catch (err) {
    console.error('List messages error:', err);
    return res.status(500).json({ error: 'Erro ao listar mensagens' });
  }
});

/**
 * POST /api/rides/:id/messages — Envia mensagem na corrida (solicitante ou motorista). Body: { text }
 */
router.post('/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const text = req.body?.text?.trim();
    if (!text || text.length === 0) {
      return res.status(400).json({ error: 'text é obrigatório.' });
    }
    const ride = await pool.query('SELECT requested_by_user_id, driver_user_id FROM rides WHERE id = $1', [id]);
    if (ride.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada' });
    }
    const { requested_by_user_id, driver_user_id } = ride.rows[0];
    const isRequester = requested_by_user_id === req.user.id;
    const isDriver = driver_user_id === req.user.id;
    if (!isRequester && !isDriver) {
      return res.status(403).json({ error: 'Apenas solicitante ou motorista podem enviar mensagens.' });
    }
    const insert = await pool.query(
      `INSERT INTO ride_messages (ride_id, user_id, text) VALUES ($1, $2, $3)
       RETURNING id, ride_id, user_id, text, created_at`,
      [id, req.user.id, text]
    );
    const row = insert.rows[0];
    return res.status(201).json({
      id: row.id,
      rideId: row.ride_id,
      userId: row.user_id,
      text: row.text,
      createdAt: row.created_at,
    });
  } catch (err) {
    console.error('Post message error:', err);
    return res.status(500).json({ error: 'Erro ao enviar mensagem' });
  }
});

/**
 * GET /api/rides/:id — Detalhe (qualquer autenticado: sua corrida, ou gestor central, ou motorista da corrida).
 * Inclui driverLat, driverLng, etaMin quando o motorista está atribuído (posição em tempo real).
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    let row;
    if (useSupabase()) {
      const { data, error } = await getSupabase().from('rides').select('*').eq('id', id).single();
      if (error || !data) {
        return res.status(404).json({ error: 'Corrida não encontrada' });
      }
      row = data;
    } else {
      const r = await pool.query(`SELECT * FROM rides WHERE id = $1`, [id]);
      if (r.rows.length === 0) {
        return res.status(404).json({ error: 'Corrida não encontrada' });
      }
      row = r.rows[0];
    }
    const isCentral = isGestorCentral(req.user);
    const isUnidade = isGestorUnidade(req.user);
    const isRequester = row.requested_by_user_id === req.user.id;
    const isDriver = row.driver_user_id === req.user.id;
    if (!isCentral && !isUnidade && !isRequester && !isDriver) {
      return res.status(403).json({ error: 'Acesso negado a esta corrida.' });
    }
    const mapped = mapRideRow(row);
    if (row.driver_user_id && ['accepted', 'driver_arrived', 'in_progress'].includes(row.status)) {
      let driverLat = null;
      let driverLng = null;
      if (useSupabase()) {
        const { data: da } = await getSupabase()
          .from('driver_availability')
          .select('lat, lng')
          .eq('user_id', row.driver_user_id)
          .maybeSingle();
        if (da?.lat != null && da?.lng != null) {
          driverLat = parseFloat(da.lat);
          driverLng = parseFloat(da.lng);
        }
      } else {
        const dr = await pool.query(
          'SELECT lat, lng FROM driver_availability WHERE user_id = $1',
          [row.driver_user_id]
        );
        if (dr.rows.length > 0 && dr.rows[0].lat != null && dr.rows[0].lng != null) {
          driverLat = parseFloat(dr.rows[0].lat);
          driverLng = parseFloat(dr.rows[0].lng);
        }
      }
      mapped.driverLat = driverLat;
      mapped.driverLng = driverLng;
      if (driverLat != null && driverLng != null && row.pickup_lat != null && row.pickup_lng != null) {
        const { durationMin } = getDistanceAndDuration(
          driverLat,
          driverLng,
          parseFloat(row.pickup_lat),
          parseFloat(row.pickup_lng)
        );
        mapped.etaMin = durationMin;
      }
    }
    return res.json(mapped);
  } catch (err) {
    console.error('Get ride error:', err);
    return res.status(500).json({ error: 'Erro ao buscar corrida' });
  }
});

export default router;
