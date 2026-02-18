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
  TablePagination,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
} from '@mui/material';
import RefreshIcon from '@mui/icons-material/Refresh';
import CancelIcon from '@mui/icons-material/Cancel';
import { listRides, cancelRide } from '../api';
import { RIDE_STATUS_LABEL } from '../types';

function timeAgo(createdAt: string | undefined): string {
  if (!createdAt) return '—';
  const diff = Date.now() - new Date(createdAt).getTime();
  const min = Math.floor(diff / 60000);
  const h = Math.floor(diff / 3600000);
  const d = Math.floor(diff / 86400000);
  if (min < 1) return 'Agora';
  if (min < 60) return `há ${min} min`;
  if (h < 24) return `há ${h} h`;
  return `há ${d} d`;
}

const CANCELABLE_STATUSES = ['requested', 'accepted', 'driver_arrived', 'in_progress'];

export default function Central() {
  const [rides, setRides] = useState<Awaited<ReturnType<typeof listRides>>>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [cancelId, setCancelId] = useState<string | null>(null);
  const [cancelReason, setCancelReason] = useState('');
  const [cancelling, setCancelling] = useState(false);

  const load = () => {
    setLoading(true);
    listRides()
      .then(setRides)
      .catch(() => setRides([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => load(), []);

  const requested = rides.filter((r) => r.status === 'requested');
  const paginated = rides.slice(page * rowsPerPage, page * rowsPerPage + rowsPerPage);

  const handleCancelClick = (id: string) => setCancelId(id);
  const handleCancelClose = () => {
    if (!cancelling) setCancelId(null);
    setCancelReason('');
  };
  const handleCancelConfirm = async () => {
    if (!cancelId) return;
    setCancelling(true);
    try {
      await cancelRide(cancelId, cancelReason || undefined);
      handleCancelClose();
      load();
    } catch (e) {
      console.error(e);
    } finally {
      setCancelling(false);
    }
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5">
          Pedidos na central
          {requested.length > 0 && (
            <Chip
              label={requested.length}
              color="warning"
              size="small"
              sx={{ ml: 1, verticalAlign: 'middle' }}
            />
          )}
        </Typography>
        <IconButton onClick={load} disabled={loading} title="Atualizar">
          <RefreshIcon />
        </IconButton>
      </Box>
      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Solicitado</TableCell>
              <TableCell>Status</TableCell>
              <TableCell>Origem</TableCell>
              <TableCell>Destino</TableCell>
              <TableCell>Valor</TableCell>
              <TableCell>Motorista</TableCell>
              <TableCell align="right">Ações</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={7}>Carregando…</TableCell>
              </TableRow>
            ) : paginated.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7}>Nenhum pedido no momento.</TableCell>
              </TableRow>
            ) : (
              paginated.map((r) => (
                <TableRow key={r.id} hover>
                  <TableCell sx={{ whiteSpace: 'nowrap' }} title={r.createdAt}>
                    {timeAgo(r.createdAt)}
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={RIDE_STATUS_LABEL[r.status] || r.status}
                      size="small"
                      color={r.status === 'requested' ? 'warning' : 'default'}
                    />
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
                  <TableCell>{r.driverName || '—'}</TableCell>
                  <TableCell align="right">
                    {CANCELABLE_STATUSES.includes(r.status) && (
                      <Button
                        size="small"
                        color="error"
                        startIcon={<CancelIcon />}
                        onClick={() => handleCancelClick(r.id)}
                      >
                        Cancelar
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
        <TablePagination
          component="div"
          count={rides.length}
          page={page}
          onPageChange={(_, p) => setPage(p)}
          rowsPerPage={rowsPerPage}
          onRowsPerPageChange={(e) => {
            setRowsPerPage(parseInt(e.target.value, 10));
            setPage(0);
          }}
          rowsPerPageOptions={[10, 25, 50]}
          labelRowsPerPage="Por página"
        />
      </TableContainer>
      <Dialog open={Boolean(cancelId)} onClose={handleCancelClose}>
        <DialogTitle>Cancelar corrida?</DialogTitle>
        <DialogContent>
          <TextField
            fullWidth
            label="Motivo (opcional)"
            value={cancelReason}
            onChange={(e) => setCancelReason(e.target.value)}
            placeholder="Ex.: passageiro desistiu"
            sx={{ mt: 1 }}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={handleCancelClose} disabled={cancelling}>
            Não
          </Button>
          <Button color="error" variant="contained" onClick={handleCancelConfirm} disabled={cancelling}>
            {cancelling ? 'Cancelando…' : 'Sim, cancelar'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
