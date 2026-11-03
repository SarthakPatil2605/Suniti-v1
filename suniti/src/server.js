import dotenv from 'dotenv';
import createApp from './app.js';
import { pool } from './config/db.js';

dotenv.config();

const app = createApp();
const PORT = process.env.PORT || 5000;

// Test DB connection asynchronously on boot
pool.query('SELECT NOW() as current_time', (err, res) => {
  if (err) {
    console.warn(
      `[Database Notice] PostgreSQL not currently reachable at ${process.env.PGHOST || 'localhost'}:${process.env.PGPORT || 5432}. ` +
      `Ensure PostgreSQL is running (e.g., run 'docker compose up -d').`
    );
  } else {
    console.log(`[Database Connected] PostgreSQL connected successfully at ${res.rows[0].current_time}`);
  }
});

const server = app.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(`🚀 Suniti CRM Auth & RBAC Server is running`);
  console.log(`📍 Port: http://localhost:${PORT}`);
  console.log(`🛡️  Auth Endpoint: POST http://localhost:${PORT}/api/auth/login`);
  console.log(`====================================================`);
});

export default server;
