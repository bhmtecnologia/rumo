import '../load-env.js';
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

-- Fase 1: Usuários e perfis de acesso (base local; depois Firebase/Google/Microsoft)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  name TEXT NOT NULL,
  profile TEXT NOT NULL CHECK (profile IN ('gestor_central', 'gestor_unidade', 'usuario')),
  reset_token TEXT,
  reset_token_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_profile ON users(profile);

-- Corridas vinculadas ao usuário solicitante (Fase 1)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'requested_by_user_id') THEN
    ALTER TABLE rides ADD COLUMN requested_by_user_id UUID REFERENCES users(id);
    CREATE INDEX idx_rides_requested_by ON rides(requested_by_user_id);
  END IF;
END $$;

-- Fase 2: Units (unidades / órgãos ou entidades)
CREATE TABLE IF NOT EXISTS units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_units_name ON units(name);

-- Centros de custo (vinculados a uma unit)
CREATE TABLE IF NOT EXISTS cost_centers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id UUID NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cost_centers_unit ON cost_centers(unit_id);

-- Usuário ↔ Centro de custo (N:N: gestor_unidade pode ter vários; usuario um)
CREATE TABLE IF NOT EXISTS user_cost_centers (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  cost_center_id UUID NOT NULL REFERENCES cost_centers(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, cost_center_id)
);

CREATE INDEX IF NOT EXISTS idx_user_cost_centers_user ON user_cost_centers(user_id);
CREATE INDEX IF NOT EXISTS idx_user_cost_centers_cc ON user_cost_centers(cost_center_id);

-- Motivos de solicitação
CREATE TABLE IF NOT EXISTS request_reasons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_request_reasons_name ON request_reasons(name);
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
