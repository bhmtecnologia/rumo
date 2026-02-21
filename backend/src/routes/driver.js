/**
 * Rotas do motorista (status online/offline) e da central (listar motoristas online).
 * PATCH /api/driver/status — Motorista: ficar online/offline, opcional enviar lat/lng.
 * GET /api/driver/online — Gestor: lista motoristas online com posição para o mapa.
 */
import { Router } from 'express';
import pool from '../db/pool.js';
import { getSupabase, useSupabase } from '../db/supabase.js';
import { isGestorCentral, isGestorUnidade, isMotorista } from '../lib/auth.js';
import { logAudit } from '../lib/audit.js';

const router = Router();

/**
 * POST /api/driver/fcm-token
 * Body: { token: string }
 * Motorista registra token FCM para receber push de nova corrida.
 */
router.post('/fcm-token', async (req, res) => {
  try {
    if (!isMotorista(req.user)) {
      return res.status(403).json({ error: 'Apenas motoristas podem registrar token FCM.' });
    }
    const { token } = req.body ?? {};
    if (!token || typeof token !== 'string' || token.length < 20) {
      return res.status(400).json({ error: 'Token FCM inválido.' });
    }
    const userId = req.user.id;

    if (useSupabase()) {
      const { error } = await getSupabase()
        .from('driver_fcm_tokens')
        .upsert(
          { user_id: userId, token: token.trim(), created_at: new Date().toISOString() },
          { onConflict: 'user_id,token' }
        );
      if (error) {
        console.error('Driver FCM token Supabase error:', error);
        return res.status(500).json({ error: 'Erro ao registrar token' });
      }
    } else {
      await pool.query(
        `INSERT INTO driver_fcm_tokens (user_id, token, created_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (user_id, token) DO UPDATE SET created_at = NOW()`,
        [userId, token.trim()]
      );
    }
    console.log('[push] Token registrado para motorista', userId);
    return res.json({ ok: true });
  } catch (err) {
    console.error('Driver FCM token error:', err);
    return res.status(500).json({ error: 'Erro ao registrar token' });
  }
});

/**
 * GET /api/driver/push-debug
 * Retorna contagem de tokens e motoristas online (para debug do push).
 */
router.get('/push-debug', async (req, res) => {
  try {
    const user = req.user;
    if (!isMotorista(user) && !isGestorCentral(user) && !isGestorUnidade(user)) {
      return res.status(403).json({ error: 'Acesso negado' });
    }
    let tokensCount = 0;
    let onlineWithTokens = 0;
    if (useSupabase()) {
      const { count: tc } = await getSupabase()
        .from('driver_fcm_tokens')
        .select('*', { count: 'exact', head: true });
      tokensCount = tc ?? 0;
      const { data: online } = await getSupabase()
        .from('driver_availability')
        .select('user_id')
        .eq('is_online', true);
      const userIds = (online || []).map((r) => r.user_id);
      if (userIds.length > 0) {
        const { count: oc } = await getSupabase()
          .from('driver_fcm_tokens')
          .select('*', { count: 'exact', head: true })
          .in('user_id', userIds);
        onlineWithTokens = oc ?? 0;
      }
    } else {
      const r1 = await pool.query('SELECT COUNT(*) AS n FROM driver_fcm_tokens');
      tokensCount = parseInt(r1.rows[0]?.n ?? 0, 10);
      const r2 = await pool.query(
        `SELECT COUNT(DISTINCT t.user_id) AS n FROM driver_fcm_tokens t
         JOIN driver_availability d ON d.user_id = t.user_id WHERE d.is_online = true`
      );
      onlineWithTokens = parseInt(r2.rows[0]?.n ?? 0, 10);
    }
    return res.json({ tokensCount, onlineWithTokens });
  } catch (err) {
    console.error('Push debug error:', err);
    return res.status(500).json({ error: 'Erro' });
  }
});

/**
 * GET /api/driver/status
 * Motorista: retorna { isOnline, lat, lng, updatedAt } do próprio registro.
 */
router.get('/status', async (req, res) => {
  try {
    if (!isMotorista(req.user)) {
      return res.status(403).json({ error: 'Apenas motoristas podem consultar status.' });
    }
    const userId = req.user.id;

    if (useSupabase()) {
      const { data, error } = await getSupabase()
        .from('driver_availability')
        .select('is_online, lat, lng, updated_at')
        .eq('user_id', userId)
        .maybeSingle();
      if (error) {
        console.error('Driver get status Supabase error:', error);
        return res.status(500).json({ error: 'Erro ao consultar status' });
      }
      if (!data) return res.json({ isOnline: false, lat: null, lng: null, updatedAt: null });
      return res.json({
        isOnline: data.is_online,
        lat: data.lat != null ? parseFloat(data.lat) : null,
        lng: data.lng != null ? parseFloat(data.lng) : null,
        updatedAt: data.updated_at,
      });
    }

    const r = await pool.query(
      'SELECT is_online, lat, lng, updated_at FROM driver_availability WHERE user_id = $1',
      [userId]
    );
    if (r.rows.length === 0) {
      return res.json({ isOnline: false, lat: null, lng: null, updatedAt: null });
    }
    const row = r.rows[0];
    return res.json({
      isOnline: row.is_online,
      lat: row.lat != null ? parseFloat(row.lat) : null,
      lng: row.lng != null ? parseFloat(row.lng) : null,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Driver get status error:', err);
    return res.status(500).json({ error: 'Erro ao consultar status' });
  }
});

/**
 * PATCH /api/driver/status
 * Body: { isOnline: boolean, lat?: number, lng?: number }
 * Apenas motorista. Cria/atualiza driver_availability.
 */
router.patch('/status', async (req, res) => {
  try {
    if (!isMotorista(req.user)) {
      return res.status(403).json({ error: 'Apenas motoristas podem alterar status online.' });
    }
    const { isOnline, lat, lng } = req.body ?? {};
    const userId = req.user.id;
    const name = req.user.name;

    if (useSupabase()) {
      const supabase = getSupabase();
      const { error } = await supabase.from('driver_availability').upsert(
        {
          user_id: userId,
          is_online: Boolean(isOnline),
          lat: lat != null ? Number(lat) : null,
          lng: lng != null ? Number(lng) : null,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id' }
      );
      if (error) {
        console.error('Driver status Supabase error:', error);
        return res.status(500).json({ error: 'Erro ao atualizar status' });
      }
      await logAudit('driver_status', userId, 'driver_availability', userId, { isOnline: Boolean(isOnline) });
      return res.json({ isOnline: Boolean(isOnline), lat: lat ?? null, lng: lng ?? null });
    }

    await pool.query(
      `INSERT INTO driver_availability (user_id, is_online, lat, lng, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (user_id) DO UPDATE SET
         is_online = $2, lat = $3, lng = $4, updated_at = NOW()`,
      [userId, Boolean(isOnline), lat != null ? Number(lat) : null, lng != null ? Number(lng) : null]
    );
    await logAudit('driver_status', userId, 'driver_availability', userId, { isOnline: Boolean(isOnline) });
    return res.json({ isOnline: Boolean(isOnline), lat: lat ?? null, lng: lng ?? null });
  } catch (err) {
    console.error('Driver status error:', err);
    return res.status(500).json({ error: 'Erro ao atualizar status' });
  }
});

/**
 * GET /api/driver/online
 * Lista motoristas online (id, name, lat, lng, updatedAt) para o mapa da central.
 * Apenas gestor_central ou gestor_unidade.
 */
router.get('/online', async (req, res) => {
  try {
    const user = req.user;
    if (!isGestorCentral(user) && !isGestorUnidade(user)) {
      return res.status(403).json({ error: 'Apenas gestores podem listar motoristas online.' });
    }

    if (useSupabase()) {
      const supabase = getSupabase();
      const { data: rows, error } = await supabase
        .from('driver_availability')
        .select('user_id, lat, lng, updated_at')
        .eq('is_online', true);
      if (error) {
        console.error('Drivers online Supabase error:', error);
        return res.status(500).json({ error: 'Erro ao listar motoristas online' });
      }
      if (!rows?.length) return res.json([]);
      const userIds = [...new Set(rows.map((r) => r.user_id))];
      const { data: users } = await supabase.from('users').select('id, name').in('id', userIds);
      const userMap = new Map((users || []).map((u) => [u.id, u]));
      const list = rows.map((r) => ({
        userId: r.user_id,
        name: userMap.get(r.user_id)?.name ?? 'Motorista',
        lat: r.lat != null ? parseFloat(r.lat) : null,
        lng: r.lng != null ? parseFloat(r.lng) : null,
        updatedAt: r.updated_at,
      }));
      return res.json(list);
    }

    const r = await pool.query(
      `SELECT d.user_id, d.lat, d.lng, d.updated_at, u.name
       FROM driver_availability d
       JOIN users u ON u.id = d.user_id
       WHERE d.is_online = true
       ORDER BY d.updated_at DESC`
    );
    const list = r.rows.map((row) => ({
      userId: row.user_id,
      name: row.name ?? 'Motorista',
      lat: row.lat != null ? parseFloat(row.lat) : null,
      lng: row.lng != null ? parseFloat(row.lng) : null,
      updatedAt: row.updated_at,
    }));
    return res.json(list);
  } catch (err) {
    console.error('Drivers online error:', err);
    return res.status(500).json({ error: 'Erro ao listar motoristas online' });
  }
});

export default router;
