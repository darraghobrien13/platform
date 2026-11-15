import type { AppType } from '@platform/api/src/app.ts';
import { hc } from 'hono/client';

// Fully typed client: routes, request bodies and responses are checked against
// the api's own code at compile time. Rename a route there -> this fails to build.
export const api = hc<AppType>('/api');
