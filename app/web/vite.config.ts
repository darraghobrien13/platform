import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  build: { outDir: 'dist/public' },
  // Local dev: same /api shape as production (the web server proxies /api/*).
  server: {
    port: 5173,
    proxy: {
      '/api': { target: 'http://localhost:8080', rewrite: (p) => p.replace(/^\/api/, '') },
    },
  },
  test: { environment: 'jsdom' },
});
