/**
 * Autenticação local (JWT). Estrutura preparada para adicionar Firebase/Google/Microsoft depois.
 */
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const SALT_ROUNDS = 10;
const JWT_SECRET = process.env.JWT_SECRET || 'rumo-dev-secret-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

export async function hashPassword(plain) {
  return bcrypt.hash(plain, SALT_ROUNDS);
}

export async function verifyPassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

export function signToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

export function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

export const PROFILES = Object.freeze({
  GESTOR_CENTRAL: 'gestor_central',
  GESTOR_UNIDADE: 'gestor_unidade',
  USUARIO: 'usuario',
  MOTORISTA: 'motorista',
});

export function hasProfile(user, profile) {
  return user && user.profile === profile;
}

export function isGestorCentral(user) {
  return hasProfile(user, PROFILES.GESTOR_CENTRAL);
}

export function isGestorUnidade(user) {
  return hasProfile(user, PROFILES.GESTOR_UNIDADE);
}

export function isUsuario(user) {
  return hasProfile(user, PROFILES.USUARIO);
}

export function isMotorista(user) {
  return hasProfile(user, PROFILES.MOTORISTA);
}
