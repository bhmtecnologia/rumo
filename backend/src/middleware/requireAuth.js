import { verifyToken } from '../lib/auth.js';

/**
 * Middleware: exige usuário autenticado (JWT no header Authorization: Bearer <token>).
 * Coloca req.user = { id, email, name, profile }.
 */
export function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Token de acesso necessário' });
  }

  try {
    const payload = verifyToken(token);
    req.user = {
      id: payload.id,
      email: payload.email,
      name: payload.name,
      profile: payload.profile,
    };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido ou expirado' });
  }
}

/**
 * Middleware: exige que o usuário tenha um dos perfis permitidos.
 * Usar depois de requireAuth.
 */
export function requireProfile(...allowedProfiles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Não autenticado' });
    }
    if (allowedProfiles.length && !allowedProfiles.includes(req.user.profile)) {
      return res.status(403).json({ error: 'Sem permissão para esta ação' });
    }
    next();
  };
}
