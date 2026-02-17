import { Router } from 'express';
import pool from '../db/pool.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireProfile } from '../middleware/requireAuth.js';

const router = Router();

router.use(requireAuth);
router.use(requireProfile('gestor_central', 'gestor_unidade'));

/**
 * GET /api/request-reasons
 */
router.get('/', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, name, created_at, updated_at FROM request_reasons ORDER BY name'
    );
    const list = r.rows.map((row) => ({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
    return res.json(list);
  } catch (err) {
    console.error('List request reasons error:', err);
    return res.status(500).json({ error: 'Erro ao listar motivos' });
  }
});

/**
 * POST /api/request-reasons
 * Body: { name }. Apenas Gestor Central.
 */
router.post('/', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Nome é obrigatório' });
    }
    const insert = await pool.query(
      'INSERT INTO request_reasons (name) VALUES ($1) RETURNING id, name, created_at, updated_at',
      [name.trim()]
    );
    const row = insert.rows[0];
    return res.status(201).json({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Create request reason error:', err);
    return res.status(500).json({ error: 'Erro ao criar motivo' });
  }
});

/**
 * PATCH /api/request-reasons/:id
 * Apenas Gestor Central.
 */
router.patch('/:id', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const { name } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Nome é obrigatório' });
    }
    const r = await pool.query(
      'UPDATE request_reasons SET name = $1, updated_at = NOW() WHERE id = $2 RETURNING id, name, created_at, updated_at',
      [name.trim(), id]
    );
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Motivo não encontrado' });
    }
    const row = r.rows[0];
    return res.json({
      id: row.id,
      name: row.name,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    });
  } catch (err) {
    console.error('Update request reason error:', err);
    return res.status(500).json({ error: 'Erro ao atualizar motivo' });
  }
});

/**
 * DELETE /api/request-reasons/:id
 * Apenas Gestor Central.
 */
router.delete('/:id', requireProfile('gestor_central'), async (req, res) => {
  try {
    const { id } = req.params;
    const r = await pool.query('DELETE FROM request_reasons WHERE id = $1 RETURNING id', [id]);
    if (r.rows.length === 0) {
      return res.status(404).json({ error: 'Motivo não encontrado' });
    }
    return res.status(204).send();
  } catch (err) {
    console.error('Delete request reason error:', err);
    return res.status(500).json({ error: 'Erro ao excluir motivo' });
  }
});

export default router;
