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
} from '@mui/material';
import RefreshIcon from '@mui/icons-material/Refresh';
import { listRides } from '../api';
import { RIDE_STATUS_LABEL } from '../types';

export default function Central() {
  const [rides, setRides] = useState<Awaited<ReturnType<typeof listRides>>>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);

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
              <TableCell>Status</TableCell>
              <TableCell>Origem</TableCell>
              <TableCell>Destino</TableCell>
              <TableCell>Valor</TableCell>
              <TableCell>Motorista</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={5}>Carregando…</TableCell>
              </TableRow>
            ) : paginated.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5}>Nenhum pedido no momento.</TableCell>
              </TableRow>
            ) : (
              paginated.map((r) => (
                <TableRow key={r.id} hover>
                  <TableCell>
                    <Chip
                      label={RIDE_STATUS_LABEL[r.status] || r.status}
                      size="small"
                      color={r.status === 'requested' ? 'warning' : 'default'}
                    />
                  </TableCell>
                  <TableCell sx={{ maxWidth: 220 }} title={r.pickupAddress}>
                    <Typography variant="body2" noWrap>
                      {r.pickupAddress}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ maxWidth: 220 }} title={r.destinationAddress}>
                    <Typography variant="body2" noWrap>
                      {r.destinationAddress}
                    </Typography>
                  </TableCell>
                  <TableCell>{r.formattedPrice}</TableCell>
                  <TableCell>{r.driverName || '—'}</TableCell>
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
    </Box>
  );
}
