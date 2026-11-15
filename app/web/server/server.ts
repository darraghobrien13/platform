// Production web server: serves the built React app and forwards /api/* to the
// api container (ADR 0008: one origin for the browser, no CORS).
import { serve } from '@hono/node-server';
import { serveStatic } from '@hono/node-server/serve-static';
import { Hono } from 'hono';
import { proxy } from 'hono/proxy';

const port = Number(process.env.PORT ?? 8080);
const version = process.env.APP_VERSION ?? 'local';
const upstream = process.env.API_UPSTREAM; // e.g. https://...-api.functions.fnc.fr-par.scw.cloud
const root = new URL('./public', import.meta.url).pathname;

const app = new Hono()
  .get('/healthz', (c) => c.json({ status: 'ok', service: 'web', version }))
  .all('/api/*', async (c) => {
    if (!upstream) return c.text('API_UPSTREAM not set', 502);
    const url = new URL(c.req.url);
    const target = upstream + url.pathname.replace(/^\/api/, '') + url.search;
    return proxy(target, { raw: c.req.raw, headers: { ...c.req.header(), host: undefined } });
  })
  .use('/*', serveStatic({ root }))
  .get('*', serveStatic({ root, path: 'index.html' })); // client-side routes

serve({ fetch: app.fetch, port }, () => console.log(`web ${version} listening on ${port}`));
