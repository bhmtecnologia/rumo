import { Router } from 'express';
import pool from '../db/pool.js';
import { hashPassword, verifyPassword, signToken } from '../lib/auth.js';
import { requireAuth } from '../middleware/requireAuth.js';
import crypto from 'crypto';

const router = Router();

/**
 * POST /api/auth/login
 * Body: { email, password }
 * Retorna: { token, user: { id, email, name, profile } }
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'E-mail e senha são obrigatórios' });
    }

    const r = await pool.query(
      'SELECT id, email, name, profile, password_hash FROM users WHERE LOWER(email) = LOWER($1)',
      [email.trim()]
    );
    if (r.rows.length === 0) {
      return res.status(401).json({ error: 'E-mail ou senha incorretos' });
    }

    const user = r.rows[0];
    const valid = await verifyPassword(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'E-mail ou senha incorretos' });
    }

    const token = signToken({
      id: user.id,
      email: user.email,
      name: user.name,
      profile: user.profile,
    });

    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        profile: user.profile,
      },
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: 'Erro ao fazer login' });
  }
});

/**
 * GET /api/auth/me
 * Requer: Authorization: Bearer <token>
 * Retorna: { user: { id, email, name, profile } }
 */
router.get('/me', requireAuth, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, email, name, profile FROM users WHERE id = $1',
      [req.user.id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }
    const row = r.rows[0];
    return res.json({
      user: {
        id: row.id,
        email: row.email,
        name: row.name,
        profile: row.profile,
      },
    });
  } catch (err) {
    console.error('Me error:', err);
    return res.status(500).json({ error: 'Erro ao buscar usuário' });
  }
});

/**
 * POST /api/auth/change-password
 * Requer: Authorization. Body: { currentPassword, newPassword }
 */
router.post('/change-password', requireAuth, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Senha atual e nova senha são obrigatórias' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'A nova senha deve ter no mínimo 6 caracteres' });
    }

    const r = await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado' });
    }
    const valid = await verifyPassword(currentPassword, r.rows[0].password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Senha atual incorreta' });
    }

    const newHash = await hashPassword(newPassword);
    await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [newHash, req.user.id]
    );
    return res.json({ ok: true, message: 'Senha alterada com sucesso' });
  } catch (err) {
    console.error('Change password error:', err);
    return res.status(500).json({ error: 'Erro ao alterar senha' });
  }
});

/**
 * POST /api/auth/forgot-password
 * Body: { email }
 * Gera token de recuperação e envia por e-mail (stub: log ou envio real se configurado).
 */
router.post('/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email || !String(email).trim()) {
      return res.status(400).json({ error: 'E-mail é obrigatório' });
    }

    const r = await pool.query('SELECT id, name FROM users WHERE LOWER(email) = LOWER($1)', [
      email.trim(),
    ]);
    // Não revelar se o e-mail existe ou não (segurança)
    if (r.rows.length === 0) {
      return res.json({
        ok: true,
        message: 'Se este e-mail estiver cadastrado, você receberá instruções para redefinir a senha.',
      });
    }

    const user = r.rows[0];
    const rawToken = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hora

    await pool.query(
      'UPDATE users SET reset_token = $1, reset_token_expires_at = $2, updated_at = NOW() WHERE id = $3',
      [hashedToken, expiresAt, user.id]
    );

    // TODO: integrar com serviço de e-mail (SendGrid, SES, etc.). Por ora apenas log.
    const resetLink = `${process.env.APP_URL || 'http://localhost:3001'}/reset-password?token=${rawToken}`;
    console.log('[forgot-password] Reset link for', user.id, ':', resetLink);

    return res.json({
      ok: true,
      message: 'Se este e-mail estiver cadastrado, você receberá instruções para redefinir a senha.',
    });
  } catch (err) {
    console.error('Forgot password error:', err);
    return res.status(500).json({ error: 'Erro ao processar solicitação' });
  }
});

/**
 * POST /api/auth/reset-password
 * Body: { token, newPassword }
 * Redefine a senha usando o token enviado por e-mail.
 */
router.post('/reset-password', async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    if (!token || !newPassword) {
      return res.status(400).json({ error: 'Token e nova senha são obrigatórios' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'A nova senha deve ter no mínimo 6 caracteres' });
    }

    const hashedToken = crypto.createHash('sha256').update(token).digest('hex');
    const r = await pool.query(
      'SELECT id FROM users WHERE reset_token = $1 AND reset_token_expires_at > NOW()',
      [hashedToken]
    );
    if (r.rows.length === 0) {
      return res.status(400).json({ error: 'Token inválido ou expirado' });
    }

    const userId = r.rows[0].id;
    const newHash = await hashPassword(newPassword);
    await pool.query(
      'UPDATE users SET password_hash = $1, reset_token = NULL, reset_token_expires_at = NULL, updated_at = NOW() WHERE id = $2',
      [newHash, userId]
    );

    return res.json({ ok: true, message: 'Senha redefinida com sucesso' });
  } catch (err) {
    console.error('Reset password error:', err);
    return res.status(500).json({ error: 'Erro ao redefinir senha' });
  }
});

/**
 * POST /api/auth/register
 * Body: { email, password, name, profile }
 * Cria usuário (útil para seed ou quando cadastro for liberado). Gestor Central pode criar outros.
 */
router.post('/register', async (req, res) => {
  try {
    const { email, password, name, profile } = req.body;
    if (!email || !password || !name || !profile) {
      return res.status(400).json({
        error: 'E-mail, senha, nome e perfil são obrigatórios',
      });
    }
    const allowedProfiles = ['gestor_central', 'gestor_unidade', 'usuario'];
    if (!allowedProfiles.includes(profile)) {
      return res.status(400).json({ error: 'Perfil inválido' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'A senha deve ter no mínimo 6 caracteres' });
    }

    const emailNorm = email.trim().toLowerCase();
    const passwordHash = await hashPassword(password);

    const insert = await pool.query(
      `INSERT INTO users (email, password_hash, name, profile)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, name, profile, created_at`,
      [emailNorm, passwordHash, name.trim(), profile]
    );
    const user = insert.rows[0];
    const token = signToken({
      id: user.id,
      email: user.email,
      name: user.name,
      profile: user.profile,
    });
    return res.status(201).json({
      token,
      user: { id: user.id, email: user.email, name: user.name, profile: user.profile },
    });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Este e-mail já está cadastrado' });
    }
    console.error('Register error:', err);
    return res.status(500).json({ error: 'Erro ao cadastrar usuário' });
  }
});

export default router;
