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

-- Fase 3: Limites e restrições por centro de custo
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cost_centers' AND column_name = 'blocked') THEN
    ALTER TABLE cost_centers ADD COLUMN blocked BOOLEAN NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cost_centers' AND column_name = 'monthly_limit_cents') THEN
    ALTER TABLE cost_centers ADD COLUMN monthly_limit_cents INT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cost_centers' AND column_name = 'max_km') THEN
    ALTER TABLE cost_centers ADD COLUMN max_km DECIMAL(6, 2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cost_centers' AND column_name = 'allowed_time_start') THEN
    ALTER TABLE cost_centers ADD COLUMN allowed_time_start TIME;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cost_centers' AND column_name = 'allowed_time_end') THEN
    ALTER TABLE cost_centers ADD COLUMN allowed_time_end TIME;
  END IF;
END $$;

-- Áreas permitidas (origem/destino): círculo lat,lng,radius_km por centro de custo
CREATE TABLE IF NOT EXISTS cost_center_allowed_areas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cost_center_id UUID NOT NULL REFERENCES cost_centers(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('origin', 'destination')),
  lat DECIMAL(10, 8) NOT NULL,
  lng DECIMAL(11, 8) NOT NULL,
  radius_km DECIMAL(6, 2) NOT NULL DEFAULT 5,
  label TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cc_allowed_areas_cc ON cost_center_allowed_areas(cost_center_id);

-- Corrida vinculada a centro de custo (para limites e restrições)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'cost_center_id') THEN
    ALTER TABLE rides ADD COLUMN cost_center_id UUID REFERENCES cost_centers(id);
    CREATE INDEX idx_rides_cost_center ON rides(cost_center_id);
  END IF;
END $$;

-- Fase 4: Fluxo completo da corrida (motorista, estados, timestamps, avaliação)
-- Perfil motorista (permite DROP/ADD mesmo que constraint tenha outro nome)
DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT conname INTO cname FROM pg_constraint WHERE conrelid = 'users'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%profile%' LIMIT 1;
  IF cname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE users DROP CONSTRAINT %I', cname);
  END IF;
  ALTER TABLE users ADD CONSTRAINT users_profile_check CHECK (profile IN ('gestor_central', 'gestor_unidade', 'usuario', 'motorista'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Status driver_arrived em rides
DO $$
DECLARE
  cname TEXT;
BEGIN
  SELECT conname INTO cname FROM pg_constraint WHERE conrelid = 'rides'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%status%' LIMIT 1;
  IF cname IS NOT NULL THEN
    EXECUTE format('ALTER TABLE rides DROP CONSTRAINT %I', cname);
  END IF;
  ALTER TABLE rides ADD CONSTRAINT rides_status_check CHECK (status IN ('requested', 'accepted', 'driver_arrived', 'in_progress', 'completed', 'cancelled'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Motorista e veículo
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'driver_user_id') THEN
    ALTER TABLE rides ADD COLUMN driver_user_id UUID REFERENCES users(id);
    ALTER TABLE rides ADD COLUMN driver_name TEXT;
    ALTER TABLE rides ADD COLUMN vehicle_plate TEXT;
    CREATE INDEX idx_rides_driver ON rides(driver_user_id);
  END IF;
END $$;

-- Timestamps do fluxo
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'accepted_at') THEN
    ALTER TABLE rides ADD COLUMN accepted_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'driver_arrived_at') THEN
    ALTER TABLE rides ADD COLUMN driver_arrived_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'started_at') THEN
    ALTER TABLE rides ADD COLUMN started_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'completed_at') THEN
    ALTER TABLE rides ADD COLUMN completed_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'cancelled_at') THEN
    ALTER TABLE rides ADD COLUMN cancelled_at TIMESTAMPTZ;
  END IF;
END $$;

-- Valores efetivos e cancelamento
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'actual_price_cents') THEN
    ALTER TABLE rides ADD COLUMN actual_price_cents INT;
    ALTER TABLE rides ADD COLUMN actual_distance_km DECIMAL(6, 2);
    ALTER TABLE rides ADD COLUMN actual_duration_min INT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'cancel_reason') THEN
    ALTER TABLE rides ADD COLUMN cancel_reason TEXT;
    ALTER TABLE rides ADD COLUMN cancelled_by_user_id UUID REFERENCES users(id);
  END IF;
END $$;

-- Trajetória (pontos lat/lng) e avaliação
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'trajectory') THEN
    ALTER TABLE rides ADD COLUMN trajectory JSONB DEFAULT '[]';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'rides' AND column_name = 'rating') THEN
    ALTER TABLE rides ADD COLUMN rating SMALLINT CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5));
  END IF;
END $$;

-- Fase 6: Comunicação usuário–motorista (mensagens da corrida)
CREATE TABLE IF NOT EXISTS ride_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ride_messages_ride ON ride_messages(ride_id);

-- Fase 7: Log de auditoria (eventos críticos)
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  resource_type TEXT,
  resource_id TEXT,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_created ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_event ON audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_resource ON audit_log(resource_type, resource_id);

-- Motorista online/offline e posição para mapa da central
CREATE TABLE IF NOT EXISTS driver_availability (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  is_online BOOLEAN NOT NULL DEFAULT false,
  lat DECIMAL(10, 8),
  lng DECIMAL(11, 8),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_driver_availability_online ON driver_availability(is_online) WHERE is_online = true;

-- Tokens FCM para push em motoristas (nova corrida)
CREATE TABLE IF NOT EXISTS driver_fcm_tokens (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_driver_fcm_tokens_user ON driver_fcm_tokens(user_id);

-- Tokens FCM para push em passageiros (motorista aceitou)
CREATE TABLE IF NOT EXISTS passenger_fcm_tokens (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_passenger_fcm_tokens_user ON passenger_fcm_tokens(user_id);
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
