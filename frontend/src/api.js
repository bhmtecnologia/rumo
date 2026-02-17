const API = '/api';

export async function getEstimate(body) {
  const res = await fetch(`${API}/rides/estimate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Erro ao calcular preço');
  }
  return res.json();
}

export async function createRide(body) {
  const res = await fetch(`${API}/rides`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data.error || 'Erro ao solicitar corrida');
  }
  return res.json();
}

export async function getRide(id) {
  const res = await fetch(`${API}/rides/${id}`);
  if (!res.ok) throw new Error('Corrida não encontrada');
  return res.json();
}
