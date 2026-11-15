import { drizzle } from 'drizzle-orm/node-postgres';
import pg from 'pg';
import * as schema from './schema.ts';

export function createDb(connectionString: string) {
  const pool = new pg.Pool({
    connectionString,
    max: 5,
    // Close idle connections quickly: an open connection keeps Serverless SQL
    // awake (and billing). With none open it scales back to zero.
    idleTimeoutMillis: 10_000,
    connectionTimeoutMillis: 15_000, // first connect after idle includes a cold start
  });
  return { db: drizzle(pool, { schema }), pool };
}

export type Db = ReturnType<typeof createDb>['db'];
