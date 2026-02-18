import { Router } from 'express';
import pool from '../db/pool.js';
import { getSupabase, useSupabase } from '../db/supabase.js';
import { hashPassword, verifyPassword, signToken } from '../lib/auth.js';
import { logAudit } from '../lib/audit.js';
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

    const emailNorm = email.trim().toLowerCase();
    console.log('[auth] login attempt', { email: emailNorm, provider: useSupabase() ? 'supabase' : 'pg' });

    let user = null;
    let costCenterIds = [];

    if (useSupabase()) {
      const supabase = getSupabase();
      const { data: users, error: userError } = await supabase
        .from('users')
        .select('id, email, name, profile, password_hash')
        .eq('email', emailNorm)
        .limit(1);
      if (userError) {
        const cause = userError.cause != null ? String(userError.cause) : undefined;
        const causeCode = userError.cause?.code ?? userError.cause?.errno;
        console.log('[auth] login supabase error', {
          email: emailNorm,
          message: userError.message,
          code: userError.code,
          cause: cause || undefined,
          causeCode,
        });
        return res.status(401).json({ error: 'E-mail ou senha incorretos' });
      }
      if (!users?.length) {
        console.log('[auth] login user not found (Supabase)', {
          email: emailNorm,
          hint: 'Se o usuário existe no banco, use SUPABASE_SERVICE_ROLE_KEY (secret), não a chave anon (RLS bloqueia).',
        });
        return res.status(401).json({ error: 'E-mail ou senha incorretos' });
      }
      user = users[0];
      const { data: ccRows } = await supabase
        .from('user_cost_centers')
        .select('cost_center_id')
        .eq('user_id', user.id);
      costCenterIds = (ccRows || []).map((r) => r.cost_center_id);
    } else {
      const r = await pool.query(
        'SELECT id, email, name, profile, password_hash FROM users WHERE LOWER(email) = LOWER($1)',
        [email.trim()]
      );
      if (r.rows.length === 0) {
        console.log('[auth] login user not found (pg)', { email: emailNorm });
        return res.status(401).json({ error: 'E-mail ou senha incorretos' });
      }
      user = r.rows[0];
      const ccRows = await pool.query(
        'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
        [user.id]
      );
      costCenterIds = ccRows.rows.map((r) => r.cost_center_id);
    }

    const valid = await verifyPassword(password, user.password_hash);
    if (!valid) {
      console.log('[auth] login invalid password', { email: emailNorm, userId: user.id });
      return res.status(401).json({ error: 'E-mail ou senha incorretos' });
    }

    console.log('[auth] login ok', { email: emailNorm, userId: user.id });

    const token = signToken({
      id: user.id,
      email: user.email,
      name: user.name,
      profile: user.profile,
    });
    await logAudit('auth_login', user.id, 'user', user.id, { email: user.email });
    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        profile: user.profile,
        costCenterIds,
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
    let row = null;
    let costCenterIds = [];

    if (useSupabase()) {
      const supabase = getSupabase();
      const { data: userRow, error: userError } = await supabase
        .from('users')
        .select('id, email, name, profile')
        .eq('id', req.user.id)
        .limit(1)
        .maybeSingle();
      if (userError || !userRow) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }
      row = userRow;
      const { data: ccRows } = await supabase
        .from('user_cost_centers')
        .select('cost_center_id')
        .eq('user_id', row.id);
      costCenterIds = (ccRows || []).map((r) => r.cost_center_id);
    } else {
      const r = await pool.query(
        'SELECT id, email, name, profile FROM users WHERE id = $1',
        [req.user.id]
      );
      if (r.rows.length === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }
      row = r.rows[0];
      const ccRows = await pool.query(
        'SELECT cost_center_id FROM user_cost_centers WHERE user_id = $1',
        [row.id]
      );
      costCenterIds = ccRows.rows.map((r) => r.cost_center_id);
    }

    return res.json({
      user: {
        id: row.id,
        email: row.email,
        name: row.name,
        profile: row.profile,
        costCenterIds,
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

    let passwordHash = null;
    if (useSupabase()) {
      const { data, error } = await getSupabase()
        .from('users')
        .select('password_hash')
        .eq('id', req.user.id)
        .limit(1)
        .maybeSingle();
      if (error || !data) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }
      passwordHash = data.password_hash;
    } else {
      const r = await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
      if (r.rows.length === 0) {
        return res.status(404).json({ error: 'Usuário não encontrado' });
      }
      passwordHash = r.rows[0].password_hash;
    }
    const valid = await verifyPassword(currentPassword, passwordHash);
    if (!valid) {
      return res.status(401).json({ error: 'Senha atual incorreta' });
    }

    const newHash = await hashPassword(newPassword);
    if (useSupabase()) {
      await getSupabase()
        .from('users')
        .update({ password_hash: newHash, updated_at: new Date().toISOString() })
        .eq('id', req.user.id);
    } else {
      await pool.query(
        'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
        [newHash, req.user.id]
      );
    }
    await logAudit('auth_password_changed', req.user.id, 'user', req.user.id, {});
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

    const emailNorm = email.trim().toLowerCase();
    let user = null;
    if (useSupabase()) {
      const { data } = await getSupabase()
        .from('users')
        .select('id, name')
        .ilike('email', emailNorm)
        .limit(1)
        .maybeSingle();
      user = data;
    } else {
      const r = await pool.query('SELECT id, name FROM users WHERE LOWER(email) = LOWER($1)', [
        email.trim(),
      ]);
      user = r.rows[0] ?? null;
    }
    if (!user) {
      return res.json({
        ok: true,
        message: 'Se este e-mail estiver cadastrado, você receberá instruções para redefinir a senha.',
      });
    }

    const rawToken = crypto.randomBytes(32).toString('hex');
    const hashedToken = crypto.createHash('sha256').update(rawToken).digest('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString(); // 1 hora

    if (useSupabase()) {
      await getSupabase()
        .from('users')
        .update({
          reset_token: hashedToken,
          reset_token_expires_at: expiresAt,
          updated_at: new Date().toISOString(),
        })
        .eq('id', user.id);
    } else {
      await pool.query(
        'UPDATE users SET reset_token = $1, reset_token_expires_at = $2, updated_at = NOW() WHERE id = $3',
        [hashedToken, expiresAt, user.id]
      );
    }

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
    const now = new Date().toISOString();
    let userId = null;
    if (useSupabase()) {
      const { data, error } = await getSupabase()
        .from('users')
        .select('id')
        .eq('reset_token', hashedToken)
        .gt('reset_token_expires_at', now)
        .limit(1)
        .maybeSingle();
      if (error || !data) {
        return res.status(400).json({ error: 'Token inválido ou expirado' });
      }
      userId = data.id;
    } else {
      const r = await pool.query(
        'SELECT id FROM users WHERE reset_token = $1 AND reset_token_expires_at > NOW()',
        [hashedToken]
      );
      if (r.rows.length === 0) {
        return res.status(400).json({ error: 'Token inválido ou expirado' });
      }
      userId = r.rows[0].id;
    }

    const newHash = await hashPassword(newPassword);
    if (useSupabase()) {
      await getSupabase()
        .from('users')
        .update({
          password_hash: newHash,
          reset_token: null,
          reset_token_expires_at: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', userId);
    } else {
      await pool.query(
        'UPDATE users SET password_hash = $1, reset_token = NULL, reset_token_expires_at = NULL, updated_at = NOW() WHERE id = $2',
        [newHash, userId]
      );
    }
    await logAudit('auth_password_reset', userId, 'user', userId, {});
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
    const allowedProfiles = ['gestor_central', 'gestor_unidade', 'usuario', 'motorista'];
    if (!allowedProfiles.includes(profile)) {
      return res.status(400).json({ error: 'Perfil inválido' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'A senha deve ter no mínimo 6 caracteres' });
    }

    const emailNorm = email.trim().toLowerCase();
    const passwordHash = await hashPassword(password);
    let user = null;

    if (useSupabase()) {
      const { data, error } = await getSupabase()
        .from('users')
        .insert({
          email: emailNorm,
          password_hash: passwordHash,
          name: name.trim(),
          profile,
        })
        .select('id, email, name, profile, created_at')
        .single();
      if (error) {
        if (error.code === '23505') {
          return res.status(409).json({ error: 'Este e-mail já está cadastrado' });
        }
        throw error;
      }
      user = data;
    } else {
      const insert = await pool.query(
        `INSERT INTO users (email, password_hash, name, profile)
         VALUES ($1, $2, $3, $4)
         RETURNING id, email, name, profile, created_at`,
        [emailNorm, passwordHash, name.trim(), profile]
      );
      user = insert.rows[0];
    }

    const token = signToken({
      id: user.id,
      email: user.email,
      name: user.name,
      profile: user.profile,
    });
    await logAudit('auth_register', user.id, 'user', user.id, { email: user.email, profile });
    return res.status(201).json({
      token,
      user: { id: user.id, email: user.email, name: user.name, profile: user.profile, costCenterIds: [] },
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
