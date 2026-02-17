import 'dotenv/config';
import pool from './pool.js';

const SQL = `
-- Tarifa base (em centavos) e por km/minuto
CREATE TABLE IF NOT EXISTS fare_config (
  id SERIAL PRIMARY KEY,
  base_fare_cents INT NOT NULL DEFAULT 500,
  per_km_cents INT NOT NULL DEFAULT 250,
  per_minute_cents INT NOT NULL DEFAULT 50,
  min_fare_cents INT NOT NULL DEFAULT 800,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO fare_config (base_fare_cents, per_km_cents, per_minute_cents, min_fare_cents)
SELECT 500, 250, 50, 800
WHERE NOT EXISTS (SELECT 1 FROM fare_config LIMIT 1);

-- Corridas
CREATE TABLE IF NOT EXISTS rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pickup_address TEXT NOT NULL,
  pickup_lat DECIMAL(10, 8),
  pickup_lng DECIMAL(11, 8),
  destination_address TEXT NOT NULL,
  destination_lat DECIMAL(10, 8),
  destination_lng DECIMAL(11, 8),
  estimated_distance_km DECIMAL(6, 2),
  estimated_duration_min INT,
  estimated_price_cents INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'in_progress', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_created_at ON rides(created_at DESC);
`;

async function migrate() {
  const client = await pool.connect();
  try {
    await client.query(SQL);
    console.log('Migration completed.');
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
