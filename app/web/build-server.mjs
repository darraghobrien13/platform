// Bundle the production web server into one file (no node_modules at runtime).
import { build } from 'esbuild';

await build({
  entryPoints: ['server/server.ts'],
  outfile: 'dist/server.js',
  bundle: true,
  platform: 'node',
  target: 'node24',
  format: 'esm',
  sourcemap: true,
  logLevel: 'info',
});
