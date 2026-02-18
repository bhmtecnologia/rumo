import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Alert,
  IconButton,
} from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import RefreshIcon from '@mui/icons-material/Refresh';
import {
  listUsers,
  createUser,
  getProfileLabel,
  type UserListItem,
} from '../api';
import type { User } from '../types';

const PROFILES = [
  { value: 'motorista', label: 'Motorista' },
  { value: 'usuario', label: 'Usuário (passageiro)' },
  { value: 'gestor_unidade', label: 'Gestor unidade' },
  { value: 'gestor_central', label: 'Gestor central' },
];

export default function Usuarios({ user }: { user: User }) {
  const [users, setUsers] = useState<UserListItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [open, setOpen] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    email: '',
    password: '',
    name: '',
    profile: 'motorista',
  });

  const canCreate = user.profile === 'gestor_central';

  const load = () => {
    setLoading(true);
    setError(null);
    listUsers()
      .then(setUsers)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  };

  useEffect(() => load(), []);

  const handleOpen = () => {
    setForm({ email: '', password: '', name: '', profile: 'motorista' });
    setSubmitError(null);
    setOpen(true);
  };

  const handleClose = () => setOpen(false);

  const handleSubmit = () => {
    if (!form.email.trim() || !form.password || !form.name.trim()) {
      setSubmitError('Preencha e-mail, senha e nome.');
      return;
    }
    if (form.password.length < 6) {
      setSubmitError('Senha deve ter no mínimo 6 caracteres.');
      return;
    }
    setSubmitting(true);
    setSubmitError(null);
    createUser({
      email: form.email.trim(),
      password: form.password,
      name: form.name.trim(),
      profile: form.profile,
    })
      .then(() => {
        handleClose();
        load();
      })
      .catch((e) => setSubmitError(e.message))
      .finally(() => setSubmitting(false));
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', mb: 2 }}>
        <Typography variant="h5">Usuários</Typography>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <IconButton onClick={load} disabled={loading} title="Atualizar">
            <RefreshIcon />
          </IconButton>
          {canCreate && (
            <Button variant="contained" startIcon={<AddIcon />} onClick={handleOpen}>
              Novo usuário
            </Button>
          )}
        </Box>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      <TableContainer component={Paper} variant="outlined">
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Nome</TableCell>
              <TableCell>E-mail</TableCell>
              <TableCell>Perfil</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {loading ? (
              <TableRow>
                <TableCell colSpan={3}>Carregando…</TableCell>
              </TableRow>
            ) : (
              users.map((u) => (
                <TableRow key={u.id}>
                  <TableCell>{u.name}</TableCell>
                  <TableCell>{u.email}</TableCell>
                  <TableCell>{getProfileLabel(u.profile)}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>

      {canCreate && (
        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
          Crie um usuário com perfil <strong>Motorista</strong> para que ele possa entrar no app
          motorista (Rumo web) e aceitar corridas.
        </Typography>
      )}

      <Dialog open={open} onClose={handleClose} maxWidth="sm" fullWidth>
        <DialogTitle>Novo usuário</DialogTitle>
        <DialogContent>
          {submitError && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setSubmitError(null)}>
              {submitError}
            </Alert>
          )}
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
            <TextField
              label="Nome"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              fullWidth
              required
            />
            <TextField
              label="E-mail"
              type="email"
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
              fullWidth
              required
            />
            <TextField
              label="Senha (mín. 6 caracteres)"
              type="password"
              value={form.password}
              onChange={(e) => setForm((f) => ({ ...f, password: e.target.value }))}
              fullWidth
              required
            />
            <FormControl fullWidth>
              <InputLabel>Perfil</InputLabel>
              <Select
                value={form.profile}
                label="Perfil"
                onChange={(e) => setForm((f) => ({ ...f, profile: e.target.value }))}
              >
                {PROFILES.map((p) => (
                  <MenuItem key={p.value} value={p.value}>
                    {p.label}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancelar</Button>
          <Button onClick={handleSubmit} variant="contained" disabled={submitting}>
            {submitting ? 'Cadastrando…' : 'Cadastrar'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
