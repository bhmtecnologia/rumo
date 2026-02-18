import { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  IconButton,
} from '@mui/material';
import RefreshIcon from '@mui/icons-material/Refresh';
import { listRides } from '../api';
import { RIDE_STATUS_LABEL } from '../types';

const ACTIVE_STATUSES = ['accepted', 'driver_arrived', 'in_progress'];

export default function Atendimento() {
  const [rides, setRides] = useState<Awaited<ReturnType<typeof listRides>>>([]);
  const [loading, setLoading] = useState(true);

  const load = () => {
    setLoading(true);
    listRides()
      .then(setRides)
      .catch(() => setRides([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => load(), []);

  const active = rides.filter((r) => ACTIVE_STATUSES.includes(r.status));

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5">Quem está atendendo</Typography>
        <IconButton onClick={load} disabled={loading} title="Atualizar">
          <RefreshIcon />
        </IconButton>
      </Box>
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Status</TableCell>
              <TableCell>Motorista / Veículo</TableCell>
              <TableCell>Origem</TableCell>
              <TableCell>Destino</TableCell>
              <TableCell>Valor</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={5}>Carregando…</TableCell>
              </TableRow>
            ) : active.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5}>Nenhuma corrida em atendimento no momento.</TableCell>
              </TableRow>
            ) : (
              active.map((r) => (
                <TableRow key={r.id} hover>
                  <TableCell>
                    <Chip
                      label={RIDE_STATUS_LABEL[r.status] || r.status}
                      size="small"
                      color="primary"
                    />
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" fontWeight="medium">
                      {r.driverName || '—'}
                    </Typography>
                    {r.vehiclePlate && (
                      <Typography variant="caption" color="text.secondary">
                        {r.vehiclePlate}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell sx={{ maxWidth: 200 }} title={r.pickupAddress}>
                    <Typography variant="body2" noWrap>
                      {r.pickupAddress}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ maxWidth: 200 }} title={r.destinationAddress}>
                    <Typography variant="body2" noWrap>
                      {r.destinationAddress}
                    </Typography>
                  </TableCell>
                  <TableCell>{r.formattedPrice}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
