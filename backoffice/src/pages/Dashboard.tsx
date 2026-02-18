import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Grid, Card, CardContent, Typography, Button, Chip } from '@mui/material';
import ListAltIcon from '@mui/icons-material/ListAlt';
import MapIcon from '@mui/icons-material/Map';
import PersonIcon from '@mui/icons-material/Person';
import { listRides } from '../api';
import { RIDE_STATUS_LABEL } from '../types';

export default function Dashboard() {
  const [rides, setRides] = useState<Awaited<ReturnType<typeof listRides>>>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    listRides()
      .then(setRides)
      .catch(() => setRides([]))
      .finally(() => setLoading(false));
  }, []);

  const requested = rides.filter((r) => r.status === 'requested');
  const active = rides.filter((r) =>
    ['accepted', 'driver_arrived', 'in_progress'].includes(r.status)
  );

  return (
    <Box>
      <Typography variant="h5" gutterBottom>
        Visão geral
      </Typography>
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Aguardando motorista
              </Typography>
              <Typography variant="h4">{requested.length}</Typography>
              <Button
                size="small"
                startIcon={<ListAltIcon />}
                onClick={() => navigate('/central')}
                sx={{ mt: 1 }}
              >
                Ver central
              </Button>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Em atendimento
              </Typography>
              <Typography variant="h4">{active.length}</Typography>
              <Button
                size="small"
                startIcon={<PersonIcon />}
                onClick={() => navigate('/atendimento')}
                sx={{ mt: 1 }}
              >
                Quem está atendendo
              </Button>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography color="text.secondary" gutterBottom>
                Mapa
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Parceiros e corridas
              </Typography>
              <Button
                size="small"
                startIcon={<MapIcon />}
                onClick={() => navigate('/mapa')}
                sx={{ mt: 1 }}
              >
                Abrir mapa
              </Button>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
      <Typography variant="h6" sx={{ mb: 2 }}>
        Últimos pedidos
      </Typography>
      {loading ? (
        <Typography color="text.secondary">Carregando…</Typography>
      ) : rides.length === 0 ? (
        <Typography color="text.secondary">Nenhuma corrida no momento.</Typography>
      ) : (
        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
          {rides.slice(0, 10).map((r) => (
            <Card key={r.id} variant="outlined" sx={{ minWidth: 280, maxWidth: 360 }}>
              <CardContent sx={{ py: 1.5, '&:last-child': { pb: 1.5 } }}>
                <Chip
                  label={RIDE_STATUS_LABEL[r.status] || r.status}
                  size="small"
                  color={r.status === 'requested' ? 'warning' : 'default'}
                  sx={{ mb: 1 }}
                />
                <Typography variant="body2" noWrap>
                  {r.pickupAddress} → {r.destinationAddress}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {r.formattedPrice}
                  {r.driverName ? ` · ${r.driverName}` : ''}
                </Typography>
              </CardContent>
            </Card>
          ))}
        </Box>
      )}
    </Box>
  );
}
