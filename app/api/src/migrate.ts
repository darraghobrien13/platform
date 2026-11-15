// Applies pending migrations from ./drizzle. Run by the deploy pipeline as the
// migrate-<env> identity BEFORE the new app version starts (ADR 0009). The
// running app (app-<env>) cannot change the schema.
import { fileURLToPath } from 'node:url';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import pg from 'pg';

const url = process.env.DATABASE_URL;
if (!url) throw new Error('DATABASE_URL is not set');

// Works from source (src/../drizzle) and from the bundle (dist/../drizzle).
const migrationsFolder = fileURLToPath(new URL('../drizzle', import.meta.url));

const pool = new pg.Pool({ connectionString: url, max: 1, connectionTimeoutMillis: 30_000 });
try {
  await migrate(drizzle(pool), { migrationsFolder });
  console.log('migrations up to date');
} finally {
  await pool.end();
}
