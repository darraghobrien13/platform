import { describe, expect, it } from 'vitest';
import { createApp } from '../src/app.ts';
import type { Db } from '../src/db.ts';

// Unit tests: no database. getDb throws if anything tries to use it.
const noDb = (): Db => {
  throw new Error('database must not be touched');
};
const app = createApp(noDb, 'test-sha');

describe('api (no database)', () => {
  it('/healthz answers without touching the database', async () => {
    const res = await app.request('/healthz');
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: 'ok', service: 'api', version: 'test-sha' });
  });

  it('rejects an empty note before reaching the database', async () => {
    const res = await app.request('/notes', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: '   ' }),
    });
    expect(res.status).toBe(400);
  });

  it('rejects a non-numeric id', async () => {
    const res = await app.request('/notes/abc', { method: 'DELETE' });
    expect(res.status).toBe(400);
  });
});
