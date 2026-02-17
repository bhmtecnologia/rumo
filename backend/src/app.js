import express from 'express';
import cors from 'cors';
import ridesRouter from './routes/rides.js';

const app = express();

app.use(cors({ origin: true }));
app.use(express.json());

app.use('/api/rides', ridesRouter);
app.get('/health', (_, res) => res.json({ ok: true }));

export default app;
