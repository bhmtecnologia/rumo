import express from 'express';
import cors from 'cors';
import ridesRouter from './routes/rides.js';
import authRouter from './routes/auth.js';
import { requireAuth } from './middleware/requireAuth.js';

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

app.use('/api/auth', authRouter);
app.use('/api/rides', requireAuth, ridesRouter);
app.get('/health', (_, res) => res.json({ ok: true }));

export default app;
