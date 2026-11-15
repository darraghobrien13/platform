import { zValidator } from '@hono/zod-validator';
import { type Health, NewNoteSchema, type Note } from '@platform/shared';
import { desc, eq, sql } from 'drizzle-orm';
import { Hono } from 'hono';
import { z } from 'zod';
import type { Db } from './db.ts';
import { notes } from './schema.ts';

const toNote = (row: typeof notes.$inferSelect): Note => ({
  id: row.id,
  text: row.text,
  createdAt: row.createdAt.toISOString(),
});

// `getDb` is lazy so /healthz never needs (or wakes) the database.
export function createApp(getDb: () => Db, version: string) {
  const app = new Hono()
    // Liveness: used by the platform probe. Must NOT touch the database.
    .get('/healthz', (c) => c.json<Health>({ status: 'ok', service: 'api', version }))

    // Readiness of the DB path; only the deploy smoke test calls it.
    .get('/health/db', async (c) => {
      await getDb().execute(sql`select 1`);
      return c.json({ status: 'ok', database: 'reachable' });
    })

    .get('/notes', async (c) => {
      const rows = await getDb().select().from(notes).orderBy(desc(notes.createdAt)).limit(100);
      return c.json(rows.map(toNote));
    })

    .post('/notes', zValidator('json', NewNoteSchema), async (c) => {
      const { text } = c.req.valid('json');
      const [row] = await getDb().insert(notes).values({ text }).returning();
      if (!row) throw new Error('insert returned no row');
      return c.json(toNote(row), 201);
    })

    .delete(
      '/notes/:id',
      zValidator('param', z.object({ id: z.coerce.number().int().positive() })),
      async (c) => {
        const { id } = c.req.valid('param');
        const deleted = await getDb().delete(notes).where(eq(notes.id, id)).returning();
        return deleted.length ? c.body(null, 204) : c.json({ error: 'not found' }, 404);
      },
    );

  app.onError((err, c) => {
    console.error(err);
    return c.json({ error: 'internal error' }, 500);
  });

  return app;
}

// The web app imports this TYPE to get a fully typed API client (hono/client).
export type AppType = ReturnType<typeof createApp>;
