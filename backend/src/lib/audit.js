/**
 * Log de auditoria (Fase 7).
 * Registra eventos críticos: auth, alteração de corrida, alterações cadastrais.
 * Não bloqueia a resposta em caso de falha (erro apenas logado no servidor).
 */
import pool from '../db/pool.js';
import { getSupabase, useSupabase } from '../db/supabase.js';

/**
 * Registra um evento no log de auditoria.
 * @param {string} eventType - Ex.: auth_login, auth_password_changed, ride_accepted, ride_completed, unit_created, etc.
 * @param {string|null} userId - ID do usuário que realizou a ação (null se não autenticado)
 * @param {string|null} resourceType - Ex.: ride, unit, cost_center, user, request_reason
 * @param {string|null} resourceId - ID do recurso afetado
 * @param {object|null} details - Dados adicionais (será armazenado como JSONB)
 */
export async function logAudit(eventType, userId, resourceType, resourceId, details = null) {
  try {
    if (useSupabase()) {
      await getSupabase().from('audit_log').insert({
        event_type: eventType,
        user_id: userId || null,
        resource_type: resourceType || null,
        resource_id: resourceId || null,
        details: details != null ? details : null,
      });
    } else {
      await pool.query(
        `INSERT INTO audit_log (event_type, user_id, resource_type, resource_id, details)
         VALUES ($1, $2, $3, $4, $5)`,
        [eventType, userId || null, resourceType || null, resourceId || null, details != null ? JSON.stringify(details) : null]
      );
    }
  } catch (err) {
    console.error('Audit log error:', err);
  }
}
