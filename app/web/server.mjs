// Placeholder web (Phase 4): serves a page and forwards /api/* to the api
// container (ADR 0008: one origin for the browser, no CORS). Replaced in Phase 5.
import http from 'node:http';

const port = Number(process.env.PORT ?? 8080);
const version = process.env.APP_VERSION ?? 'local';
const upstream = process.env.API_UPSTREAM; // e.g. https://...-api.functions.fnc.fr-par.scw.cloud

http
  .createServer(async (req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ status: 'ok', service: 'web', version }));
    }
    if (req.url.startsWith('/api/')) {
      if (!upstream) return res.writeHead(502).end('API_UPSTREAM not set');
      try {
        const r = await fetch(upstream + req.url.slice(4), { method: req.method });
        res.writeHead(r.status, { 'content-type': r.headers.get('content-type') ?? 'text/plain' });
        return res.end(Buffer.from(await r.arrayBuffer()));
      } catch (e) {
        return res.writeHead(502).end(`upstream error: ${e.message}`);
      }
    }
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    res.end(`<!doctype html><title>platform</title>
<h1>platform: ${process.env.APP_ENV ?? 'local'}</h1>
<p>web <code>${version}</code> (placeholder). <a href="/api/">/api/</a> is proxied to the api container.</p>`);
  })
  .listen(port, () => console.log(`web ${version} listening on ${port}`));
