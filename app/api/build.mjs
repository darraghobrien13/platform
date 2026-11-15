// Bundle each entry point into ONE self-contained file (all npm deps inlined),
// so the runtime image needs no node_modules and no npm.
import { build } from 'esbuild';

await build({
  entryPoints: ['src/server.ts', 'src/migrate.ts'],
  outdir: 'dist',
  bundle: true,
  platform: 'node',
  target: 'node24',
  format: 'esm',
  sourcemap: true,
  external: ['pg-native'], // optional native addon of pg; we use the pure-JS driver
  // Some CommonJS deps call require(); give ESM bundles a working require.
  banner: {
    js: "import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);",
  },
  logLevel: 'info',
});
