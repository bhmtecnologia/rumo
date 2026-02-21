/**
 * Rotas do passageiro (registro de token FCM para push).
 * POST /api/passenger/fcm-token — Passageiro registra token para receber push quando motorista aceita.
 */
import { Router } from 'express';
import { getSupabase, useSupabase } from '../db/supabase.js';
import pool from '../db/pool.js';

const router = Router();

function isUsuario(user) {
  return user?.profile === 'usuario';
}

/**
 * POST /api/passenger/fcm-token
 * Body: { token: string }
 */
router.post('/fcm-token', async (req, res) => {
  try {
    if (!isUsuario(req.user)) {
      return res.status(403).json({ error: 'Apenas passageiros podem registrar token FCM.' });
    }
    const { token } = req.body ?? {};
    if (!token || typeof token !== 'string' || token.length < 20) {
      return res.status(400).json({ error: 'Token FCM inválido.' });
    }
    const userId = req.user.id;

    if (useSupabase()) {
      const { error } = await getSupabase()
        .from('passenger_fcm_tokens')
        .upsert(
          { user_id: userId, token: token.trim(), created_at: new Date().toISOString() },
          { onConflict: 'user_id,token' }
        );
      if (error) {
        console.error('Passenger FCM token Supabase error:', error);
        return res.status(500).json({ error: 'Erro ao registrar token' });
      }
    } else {
      await pool.query(
        `INSERT INTO passenger_fcm_tokens (user_id, token, created_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (user_id, token) DO UPDATE SET created_at = NOW()`,
        [userId, token.trim()]
      );
    }
    console.log('[push] Token registrado para passageiro', userId);
    return res.json({ ok: true });
  } catch (err) {
    console.error('Passenger FCM token error:', err);
    return res.status(500).json({ error: 'Erro ao registrar token' });
  }
});

export default router;
