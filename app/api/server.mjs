// Placeholder API (Phase 4): proves the build -> push -> migrate -> deploy path.
// Replaced by the real TypeScript API in Phase 5.
import http from 'node:http';

const port = Number(process.env.PORT ?? 8080);
const version = process.env.APP_VERSION ?? 'local';
const json = (res, code, body) => {
  res.writeHead(code, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
};

http
  .createServer((req, res) => {
    // Liveness only: never touches the database (it would keep it awake and billing).
    if (req.url === '/healthz') return json(res, 200, { status: 'ok', service: 'api', version });
    json(res, 200, { service: 'api', env: process.env.APP_ENV, version, message: 'placeholder API' });
  })
  .listen(port, () => console.log(`api ${version} listening on ${port}`));
