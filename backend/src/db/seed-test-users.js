/**
 * Cria usuários de teste (passageiro, motorista, central) se não existirem.
 * Uso: cd backend && node src/db/seed-test-users.js
 * Senha padrão: senha123 (altere após o primeiro login)
 */
import '../load-env.js';
import pool from './pool.js';
import { getSupabase, useSupabase } from './supabase.js';
import { hashPassword } from '../lib/auth.js';

const USERS = [
  { email: 'passageiro@rumo.local', name: 'Passageiro', profile: 'usuario' },
  { email: 'motorista@rumo.local', name: 'Motorista', profile: 'motorista' },
  { email: 'central@rumo.local', name: 'Central', profile: 'gestor_central' },
];
const PASSWORD = 'senha123';

async function seedWithPool() {
  for (const u of USERS) {
    const r = await pool.query('SELECT id FROM users WHERE LOWER(email) = LOWER($1)', [u.email]);
    if (r.rows.length > 0) {
      console.log('Já existe:', u.email);
      continue;
    }
    const hash = await hashPassword(PASSWORD);
    await pool.query(
      `INSERT INTO users (email, password_hash, name, profile) VALUES ($1, $2, $3, $4)`,
      [u.email.toLowerCase(), hash, u.name, u.profile]
    );
    console.log('Criado:', u.email, '| perfil:', u.profile);
  }
  await pool.end();
}

async function seedWithSupabase() {
  const supabase = getSupabase();
  for (const u of USERS) {
    const { data: existing } = await supabase.from('users').select('id').ilike('email', u.email).maybeSingle();
    if (existing) {
      console.log('Já existe:', u.email);
      continue;
    }
    const hash = await hashPassword(PASSWORD);
    const { error } = await supabase.from('users').insert({
      email: u.email.toLowerCase(),
      password_hash: hash,
      name: u.name,
      profile: u.profile,
    });
    if (error) {
      console.error('Erro ao criar', u.email, error.message);
      continue;
    }
    console.log('Criado:', u.email, '| perfil:', u.profile);
  }
}

async function seed() {
  if (useSupabase()) {
    await seedWithSupabase();
  } else {
    await seedWithPool();
  }
  console.log('\nUsuários de teste | senha:', PASSWORD);
  console.log('Altere a senha após o primeiro login.');
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
