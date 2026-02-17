import { Router } from 'express';
import pool from '../db/pool.js';
import { calculateFare, getDistanceAndDuration } from '../lib/fare.js';
import { isGestorCentral } from '../lib/auth.js';

const router = Router();

async function getFareConfig() {
  const r = await pool.query(
    'SELECT base_fare_cents, per_km_cents, per_minute_cents, min_fare_cents FROM fare_config LIMIT 1'
  );
  return r.rows[0] || null;
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
    } = req.body;

    if (!pickupAddress || !destinationAddress || estimatedPriceCents == null) {
      return res.status(400).json({
        error: 'pickupAddress, destinationAddress e estimatedPriceCents são obrigatórios',
      });
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

    const userId = req.user?.id ?? null;
    const insert = await pool.query(
      `INSERT INTO rides (
        pickup_address, pickup_lat, pickup_lng,
        destination_address, destination_lat, destination_lng,
        estimated_distance_km, estimated_duration_min, estimated_price_cents,
        status, requested_by_user_id
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'requested', $10)
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
      ]
    );

    const ride = insert.rows[0];
    const formattedPrice = (ride.estimated_price_cents / 100).toLocaleString(
      'pt-BR',
      { style: 'currency', currency: 'BRL' }
    );

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

/**
 * GET /api/rides
 * Lista últimas corridas (para backoffice/central: mapa, SLA, analistas).
 * Deve vir ANTES de /:id para GET /api/rides não ser interpretado como id vazio.
 */
router.get('/', async (req, res) => {
  try {
    const isCentral = req.user && isGestorCentral(req.user);
    const query =
      isCentral
        ? `SELECT id, pickup_address, pickup_lat, pickup_lng,
                  destination_address, destination_lat, destination_lng,
                  estimated_distance_km, estimated_duration_min, estimated_price_cents,
                  status, created_at
           FROM rides ORDER BY created_at DESC LIMIT 100`
        : `SELECT id, pickup_address, pickup_lat, pickup_lng,
                  destination_address, destination_lat, destination_lng,
                  estimated_distance_km, estimated_duration_min, estimated_price_cents,
                  status, created_at
           FROM rides WHERE requested_by_user_id = $1 ORDER BY created_at DESC LIMIT 100`;
    const params = isCentral ? [] : [req.user.id];
    const r = await pool.query(query, params);
    const rides = r.rows.map((row) => ({
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
      formattedPrice: (row.estimated_price_cents / 100).toLocaleString(
        'pt-BR',
        { style: 'currency', currency: 'BRL' }
      ),
      status: row.status,
      createdAt: row.created_at,
    }));
    return res.json(rides);
  } catch (err) {
    console.error('List rides error:', err);
    return res.status(500).json({ error: 'Erro ao listar corridas' });
  }
});

/**
 * GET /api/rides/:id
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query(
      `SELECT id, pickup_address, pickup_lat, pickup_lng,
              destination_address, destination_lat, destination_lng,
              estimated_distance_km, estimated_duration_min, estimated_price_cents,
              status, created_at, updated_at
       FROM rides WHERE id = $1`,
      [id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Corrida não encontrada' });
    }
    const ride = r.rows[0];
    ride.formattedPrice = (ride.estimated_price_cents / 100).toLocaleString(
      'pt-BR',
      { style: 'currency', currency: 'BRL' }
    );
    return res.json(ride);
  } catch (err) {
    console.error('Get ride error:', err);
    return res.status(500).json({ error: 'Erro ao buscar corrida' });
  }
});

export default router;
