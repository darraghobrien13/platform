import { defineConfig } from 'drizzle-kit';

// `npm run db:generate -w api` diffs src/schema.ts against previous migrations
// and writes a new, reviewable SQL file into ./drizzle. Commit it.
export default defineConfig({
  dialect: 'postgresql',
  schema: './src/schema.ts',
  out: './drizzle',
});
