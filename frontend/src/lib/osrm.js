/**
 * OSRM (router.project-osrm.org) — rota pelas ruas, sem API key.
 * Retorna array de [lat, lng] para desenhar no mapa.
 */
const OSRM_BASE = 'https://router.project-osrm.org/route/v1/driving';

export async function getRoutePolyline(originLat, originLng, destLat, destLng) {
  const coords = `${originLng},${originLat};${destLng},${destLat}`;
  const url = `${OSRM_BASE}/${coords}?overview=full&geometries=geojson`;
  const res = await fetch(url);
  if (!res.ok) return null;
  const data = await res.json();
  if (data.code !== 'Ok' || !data.routes?.[0]?.geometry?.coordinates?.length) {
    return null;
  }
  const coordinates = data.routes[0].geometry.coordinates;
  return coordinates.map(([lng, lat]) => [lat, lng]);
}
