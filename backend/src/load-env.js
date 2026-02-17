/**
 * Carrega .env da raiz do projeto (rumo/.env) antes de qualquer módulo que use process.env.
 * Assim "npm run dev" em backend/ enxerga o .env que está na raiz.
 */
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
dotenv.config(); // backend/.env se existir
