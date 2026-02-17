/**
 * Haversine: distância em km entre dois pontos (lat/lng).
 */
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // raio da Terra em km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Estima duração em minutos (média ~25 km/h em cidade).
 */
function estimateDurationMinutes(distanceKm) {
  const avgSpeedKmh = 25;
  return Math.max(1, Math.round((distanceKm / avgSpeedKmh) * 60));
}

/**
 * Calcula preço em centavos: base + (km * per_km) + (min * per_min), mínimo min_fare.
 */
export function calculateFare(distanceKm, durationMin, config) {
  const base = config?.base_fare_cents ?? 500;
  const perKm = config?.per_km_cents ?? 250;
  const perMin = config?.per_minute_cents ?? 50;
  const minFare = config?.min_fare_cents ?? 800;
  const total = base + Math.round(distanceKm * perKm) + durationMin * perMin;
  return Math.max(minFare, total);
}

export function getDistanceAndDuration(pickupLat, pickupLng, destLat, destLng) {
  const distanceKm = haversineKm(
    Number(pickupLat),
    Number(pickupLng),
    Number(destLat),
    Number(destLng)
  );
  const durationMin = estimateDurationMinutes(distanceKm);
  return { distanceKm, durationMin };
}
