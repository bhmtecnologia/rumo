/**
 * Preferir IPv4 na resolução DNS (Node 17+).
 * No Render, o host do Supabase pode resolver para IPv6 e o ambiente retorna ENETUNREACH;
 * forçar IPv4 primeiro evita esse erro.
 */
import dns from 'node:dns';
try {
  if (typeof dns.setDefaultResultOrder === 'function') {
    dns.setDefaultResultOrder('ipv4first');
  }
} catch (_) {
  // Node < 17; ignora
}
