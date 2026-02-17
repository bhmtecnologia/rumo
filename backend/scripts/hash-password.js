/**
 * Gera o hash bcrypt de uma senha (para inserir usuário manualmente no Supabase, etc.).
 * Uso: node scripts/hash-password.js [senha]
 * Padrão: rumo123
 */
import { hashPassword } from '../src/lib/auth.js';

const password = process.argv[2] || 'rumo123';
const hash = await hashPassword(password);
console.log(hash);
