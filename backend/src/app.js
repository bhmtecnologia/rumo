import express from 'express';
import cors from 'cors';
import ridesRouter from './routes/rides.js';
import authRouter from './routes/auth.js';
import unitsRouter from './routes/units.js';
import costCentersRouter from './routes/costCenters.js';
import requestReasonsRouter from './routes/requestReasons.js';
import usersRouter from './routes/users.js';
import { requireAuth } from './middleware/requireAuth.js';

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

app.use('/api/auth', authRouter);
app.use('/api/rides', requireAuth, ridesRouter);
app.use('/api/units', unitsRouter);
app.use('/api/cost-centers', costCentersRouter);
app.use('/api/request-reasons', requestReasonsRouter);
app.use('/api/users', usersRouter);
app.get('/health', (_, res) => res.json({ ok: true }));

export default app;
