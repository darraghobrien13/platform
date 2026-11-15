// Integration tests against a REAL Postgres (docker compose locally, a service
// container in CI). Skipped when TEST_DATABASE_URL isn't set.
import { fileURLToPath } from 'node:url';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createApp } from '../src/app.ts';
import { createDb } from '../src/db.ts';
import { notes } from '../src/schema.ts';

const url = process.env.TEST_DATABASE_URL;

describe.skipIf(!url)('api + postgres', () => {
  const { db, pool } = createDb(url ?? '');
  const app = createApp(() => db, 'test-sha');

  beforeAll(async () => {
    await migrate(db, { migrationsFolder: fileURLToPath(new URL('../drizzle', import.meta.url)) });
    await db.delete(notes);
  });
  afterAll(() => pool.end());

  it('creates, lists and deletes a note', async () => {
    const created = await app.request('/notes', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: '  hello  ' }),
    });
    expect(created.status).toBe(201);
    const note = (await created.json()) as { id: number; text: string };
    expect(note.text).toBe('hello'); // trimmed by the shared schema

    const list = (await (await app.request('/notes')).json()) as { id: number }[];
    expect(list.map((n) => n.id)).toContain(note.id);

    expect((await app.request(`/notes/${note.id}`, { method: 'DELETE' })).status).toBe(204);
    expect((await app.request(`/notes/${note.id}`, { method: 'DELETE' })).status).toBe(404);
  });

  it('/health/db reports the database reachable', async () => {
    expect((await app.request('/health/db')).status).toBe(200);
  });
});
