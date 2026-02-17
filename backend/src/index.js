import './load-dns.js';
import './load-env.js';
import app from './app.js';

const PORT = process.env.PORT || 3001;

app.listen(PORT, () => {
  console.log(`Rumo API running at http://localhost:${PORT}`);
});
