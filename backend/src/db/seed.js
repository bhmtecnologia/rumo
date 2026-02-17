/**
 * Cria um usuário inicial se não existir nenhum.
 * Uso: node src/db/seed.js
 * Altere a senha após o primeiro login.
 */
import '../load-env.js';
import pool from './pool.js';
import { hashPassword } from '../lib/auth.js';

const DEFAULT_EMAIL = process.env.SEED_EMAIL || 'admin@rumo.local';
const DEFAULT_PASSWORD = process.env.SEED_PASSWORD || 'rumo123';
const DEFAULT_NAME = process.env.SEED_NAME || 'Administrador';
const DEFAULT_PROFILE = 'gestor_central';

async function seed() {
  const r = await pool.query('SELECT 1 FROM users LIMIT 1');
  if (r.rows.length > 0) {
    console.log('Já existem usuários. Nenhum seed aplicado.');
    await pool.end();
    return;
  }
  const hash = await hashPassword(DEFAULT_PASSWORD);
  await pool.query(
    `INSERT INTO users (email, password_hash, name, profile) VALUES ($1, $2, $3, $4)`,
    [DEFAULT_EMAIL, hash, DEFAULT_NAME, DEFAULT_PROFILE]
  );
  console.log('Usuário inicial criado:', DEFAULT_EMAIL, '| perfil:', DEFAULT_PROFILE);
  console.log('Altere a senha após o primeiro login.');
  await pool.end();
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
