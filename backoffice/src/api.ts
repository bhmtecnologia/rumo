const getToken = () => localStorage.getItem('rumo_backoffice_token');

export async function login(email: string, password: string) {
  const base = import.meta.env.VITE_API_URL || '';
  const res = await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Falha no login');
  return data;
}

export async function me(): Promise<{ user: import('./types').User }> {
  const token = getToken();
  if (!token) throw new Error('Não autenticado');
  const base = import.meta.env.VITE_API_URL || '';
  const res = await fetch(`${base}/api/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) throw new Error('Sessão expirada');
  if (!res.ok) throw new Error(data.error || 'Erro ao carregar usuário');
  return data;
}

export async function listRides(): Promise<import('./types').RideListItem[]> {
  const token = getToken();
  if (!token) throw new Error('Não autenticado');
  const base = import.meta.env.VITE_API_URL || '';
  const res = await fetch(`${base}/api/rides`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) throw new Error('Sessão expirada');
  if (!res.ok) throw new Error(data.error || 'Erro ao listar corridas');
  return Array.isArray(data) ? data : [];
}

export async function cancelRide(id: string, reason?: string): Promise<void> {
  const token = getToken();
  if (!token) throw new Error('Não autenticado');
  const base = import.meta.env.VITE_API_URL || '';
  const res = await fetch(`${base}/api/rides/${id}/cancel`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ reason: reason || undefined }),
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) throw new Error('Sessão expirada');
  if (!res.ok) throw new Error((data as { error?: string }).error || 'Erro ao cancelar corrida');
}

export interface OnlineDriver {
  userId: string;
  name: string;
  lat: number | null;
  lng: number | null;
  updatedAt: string;
}

export async function listOnlineDrivers(): Promise<OnlineDriver[]> {
  const token = getToken();
  if (!token) throw new Error('Não autenticado');
  const base = import.meta.env.VITE_API_URL || '';
  const res = await fetch(`${base}/api/driver/online`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) throw new Error('Sessão expirada');
  if (!res.ok) throw new Error((data as { error?: string }).error || 'Erro ao listar motoristas online');
  return Array.isArray(data) ? data : [];
}
