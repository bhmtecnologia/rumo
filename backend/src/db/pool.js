import pg from 'pg';

const { Pool } = pg;

/**
 * Configuração do pool de conexões PostgreSQL.
 * Supabase: use DATABASE_URL (connection string).
 * Local: use PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD ou DATABASE_URL.
 */
const config = process.env.DATABASE_URL
  ? {
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DATABASE_URL.includes('supabase') ? { rejectUnauthorized: false } : undefined,
    }
  : {
      host: process.env.PGHOST || 'localhost',
      port: parseInt(process.env.PGPORT || '5432', 10),
      database: process.env.PGDATABASE || 'rumo',
      user: process.env.PGUSER || 'rumo',
      password: process.env.PGPASSWORD || 'rumo_secret',
    };

const pool = new Pool(config);

export default pool;
