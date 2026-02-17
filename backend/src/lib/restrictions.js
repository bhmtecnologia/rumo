import pool from '../db/pool.js';

/**
 * Verifica se uma solicitação de corrida está dentro das restrições do centro de custo.
 * Retorna { allowed: boolean, error?: string }.
 */
export async function checkRestrictions(costCenterId, userId, options) {
  const {
    pickupLat,
    pickupLng,
    destinationLat,
    destinationLng,
    estimatedPriceCents,
    estimatedDistanceKm,
  } = options;

  const ccRow = await pool.query(
    `SELECT id, blocked, monthly_limit_cents, max_km, allowed_time_start, allowed_time_end
     FROM cost_centers WHERE id = $1`,
    [costCenterId]
  );
  if (ccRow.rows.length === 0) {
    return { allowed: false, error: 'Centro de custo não encontrado' };
  }
  const cc = ccRow.rows[0];

  if (cc.blocked) {
    return { allowed: false, error: 'Este centro de custo está bloqueado para solicitações.' };
  }

  const now = new Date();
  const currentTime = now.getHours() * 60 + now.getMinutes();

  if (cc.allowed_time_start != null && cc.allowed_time_end != null) {
    const [startH, startM] = cc.allowed_time_start.split(':').map(Number);
    const [endH, endM] = cc.allowed_time_end.split(':').map(Number);
    const startMin = startH * 60 + startM;
    const endMin = endH * 60 + endM;
    const crossesMidnight = endMin <= startMin;
    const inWindow = crossesMidnight
      ? currentTime >= startMin || currentTime < endMin
      : currentTime >= startMin && currentTime < endMin;
    if (!inWindow) {
      return {
        allowed: false,
        error: `Solicitações permitidas apenas entre ${cc.allowed_time_start} e ${cc.allowed_time_end}.`,
      };
    }
  }

  if (cc.max_km != null && estimatedDistanceKm != null && Number(estimatedDistanceKm) > Number(cc.max_km)) {
    return {
      allowed: false,
      error: `Quilometragem máxima permitida para este centro de custo é ${cc.max_km} km.`,
    };
  }

  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  const sumResult = await pool.query(
    `SELECT COALESCE(SUM(estimated_price_cents), 0)::bigint AS total
     FROM rides
     WHERE cost_center_id = $1 AND status != 'cancelled'
       AND EXTRACT(YEAR FROM created_at) = $2 AND EXTRACT(MONTH FROM created_at) = $3`,
    [costCenterId, year, month]
  );
  const spentCents = Number(sumResult.rows[0]?.total ?? 0);
  const newTotal = spentCents + (Number(estimatedPriceCents) || 0);
  if (cc.monthly_limit_cents != null && newTotal > Number(cc.monthly_limit_cents)) {
    return {
      allowed: false,
      error: `Limite de despesas do centro de custo para este mês foi atingido (R$ ${(cc.monthly_limit_cents / 100).toFixed(2)}).`,
    };
  }

  const areas = await pool.query(
    `SELECT type, lat, lng, radius_km FROM cost_center_allowed_areas WHERE cost_center_id = $1`,
    [costCenterId]
  );
  if (areas.rows.length > 0) {
    const originAreas = areas.rows.filter((a) => a.type === 'origin');
    const destAreas = areas.rows.filter((a) => a.type === 'destination');
    if (originAreas.length > 0 && pickupLat != null && pickupLng != null) {
      const inAny = originAreas.some((a) => {
        const d = haversineKm(Number(pickupLat), Number(pickupLng), Number(a.lat), Number(a.lng));
        return d <= Number(a.radius_km);
      });
      if (!inAny) {
        return { allowed: false, error: 'Origem não está em área permitida para este centro de custo.' };
      }
    }
    if (destAreas.length > 0 && destinationLat != null && destinationLng != null) {
      const inAny = destAreas.some((a) => {
        const d = haversineKm(Number(destinationLat), Number(destinationLng), Number(a.lat), Number(a.lng));
        return d <= Number(a.radius_km);
      });
      if (!inAny) {
        return { allowed: false, error: 'Destino não está em área permitida para este centro de custo.' };
      }
    }
  }

  return { allowed: true };
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}
