/**
 * Geocoding via OpenStreetMap Nominatim (sem API key).
 * Uso: buscar endereço -> retorna lista com lat, lon, display_name.
 * Reverse: lat/lng -> endereço.
 */

const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';
const NOMINATIM_REVERSE = 'https://nominatim.openstreetmap.org/reverse';

export async function searchAddress(query) {
  if (!query || query.trim().length < 3) return [];
  const params = new URLSearchParams({
    q: query.trim(),
    format: 'json',
    addressdetails: '1',
    limit: '6',
  });
  const res = await fetch(`${NOMINATIM_URL}?${params}`, {
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) return [];
  const data = await res.json();
  return (Array.isArray(data) ? data : []).map((item) => ({
    displayName: item.display_name,
    lat: parseFloat(item.lat),
    lon: parseFloat(item.lon),
  }));
}

export async function reverseGeocode(lat, lon) {
  const params = new URLSearchParams({
    lat: String(lat),
    lon: String(lon),
    format: 'json',
  });
  const res = await fetch(`${NOMINATIM_REVERSE}?${params}`, {
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data?.display_name ?? null;
}
