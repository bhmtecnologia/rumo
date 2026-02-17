import { Router } from 'express';
import pool from '../db/pool.js';
import { calculateFare, getDistanceAndDuration } from '../lib/fare.js';

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

    const insert = await pool.query(
      `INSERT INTO rides (
        pickup_address, pickup_lat, pickup_lng,
        destination_address, destination_lat, destination_lng,
        estimated_distance_km, estimated_duration_min, estimated_price_cents,
        status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'requested')
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
      ]
    );

    const ride = insert.rows[0];
    const formattedPrice = (ride.estimated_price_cents / 100).toLocaleString(
      'pt-BR',
      { style: 'currency', currency: 'BRL' }
    );

    return res.status(201).json({
      ...ride,
      formattedPrice,
    });
  } catch (err) {
    console.error('Create ride error:', err);
    return res.status(500).json({ error: 'Erro ao solicitar corrida' });
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

/**
 * GET /api/rides
 * Lista últimas corridas (para demonstração).
 */
router.get('/', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT id, pickup_address, destination_address, estimated_price_cents,
              status, created_at
       FROM rides ORDER BY created_at DESC LIMIT 50`
    );
    const rides = r.rows.map((row) => ({
      ...row,
      formattedPrice: (row.estimated_price_cents / 100).toLocaleString(
        'pt-BR',
        { style: 'currency', currency: 'BRL' }
      ),
    }));
    return res.json(rides);
  } catch (err) {
    console.error('List rides error:', err);
    return res.status(500).json({ error: 'Erro ao listar corridas' });
  }
});

export default router;
