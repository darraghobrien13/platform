import { serve } from '@hono/node-server';
import { createApp } from './app.ts';
import { createDb, type Db } from './db.ts';

const port = Number(process.env.PORT ?? 8080);
const version = process.env.APP_VERSION ?? 'local';

let db: Db | undefined;
const getDb = () => {
  if (!db) {
    const url = process.env.DATABASE_URL;
    if (!url) throw new Error('DATABASE_URL is not set');
    db = createDb(url).db;
  }
  return db;
};

serve({ fetch: createApp(getDb, version).fetch, port }, () =>
  console.log(`api ${version} listening on ${port}`),
);
