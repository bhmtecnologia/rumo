/**
 * Cliente Supabase para o backend.
 * Quando SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY estão definidos, use getSupabase()
 * para acessar o banco via API HTTPS (evita ENETUNREACH no Render; não usa conexão TCP).
 *
 * No Render: defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no Environment.
 * Local: pode usar DATABASE_URL + pg ou as mesmas variáveis Supabase.
 */
import { createClient } from '@supabase/supabase-js';

let _client = null;

/**
 * Retorna o cliente Supabase se as credenciais estiverem configuradas; caso contrário null.
 * @returns {import('@supabase/supabase-js').SupabaseClient | null}
 */
export function getSupabase() {
  if (_client !== null) return _client;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    return null;
  }
  try {
    const host = new URL(url).hostname;
    console.log('[auth] using Supabase for DB', { host });
  } catch (_) {}
  _client = createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  return _client;
}

/** Retorna true se o app deve usar Supabase em vez de pg para acesso a dados. */
export function useSupabase() {
  return Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);
}
