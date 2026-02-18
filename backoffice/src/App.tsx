import { useState, useEffect } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import type { User } from './types';
import { me } from './api';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Central from './pages/Central';
import Mapa from './pages/Mapa';
import Atendimento from './pages/Atendimento';

const GESTOR_PROFILES = ['gestor_central', 'gestor_unidade'];

function App() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('rumo_backoffice_token');
    if (!token) {
      setLoading(false);
      return;
    }
    me()
      .then(({ user: u }) => {
        if (GESTOR_PROFILES.includes(u.profile)) setUser(u);
        else localStorage.removeItem('rumo_backoffice_token');
      })
      .catch(() => localStorage.removeItem('rumo_backoffice_token'))
      .finally(() => setLoading(false));
  }, []);

  const onLogin = (u: User) => setUser(u);
  const onLogout = () => {
    localStorage.removeItem('rumo_backoffice_token');
    setUser(null);
  };

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        Carregando…
      </div>
    );
  }

  if (!user) {
    return <Login onLogin={onLogin} />;
  }

  return (
    <Layout user={user} onLogout={onLogout}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/central" element={<Central />} />
        <Route path="/mapa" element={<Mapa />} />
        <Route path="/atendimento" element={<Atendimento />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
}

export default App;
