# 0007. App stack: TypeScript end to end

- Status: Accepted (2026-11-15, Phase 5)
- Date: 2026-10-10

## Context
We need a simple full-stack app with a frontend, an API, and Postgres. The owner knows Python and wants to improve at TypeScript. The platform will later host Claude agents, and both Python and TypeScript have first-class Anthropic SDKs.

## Decision
- **API:** Node.js + TypeScript with **Hono**. Its typed client (`hono/client`) gives the frontend compile-time-checked API calls.
- **Frontend:** React + Vite + TypeScript.
- **Database access:** **Drizzle ORM**. `drizzle-kit` generates versioned SQL migrations into `api/drizzle/`, and they're reviewed in PRs. The deploy pipeline runs them as `migrate-<env>` before the new version starts.
- **Validation:** **Zod** schemas in `shared`, used by the API (requests) and the web app (forms).
- **Tests:** Vitest: API unit tests (no database), integration tests against a real Postgres 16 (a service container in CI, Docker Compose locally), and React component tests (Testing Library + jsdom).
- **Lint and format:** **Biome**, one tool with the `recommended` preset.
- **Packaging:** esbuild bundles each server into one file, so runtime images contain no `node_modules` and no npm (about 67 MB each).
- **Packaging:** one OCI image per service, built in CI and tagged with the git SHA.
  - Config comes from environment variables, and secrets are injected at runtime from Secret Manager.
  - Every service exposes `/healthz`.
  - The `web` container serves the frontend and forwards `/api/*` to `api` (see [0008](0008-builtin-urls-no-custom-domain.md)). Its upstream comes from the `API_UPSTREAM` environment variable.
  - These conventions keep a future move to Kubernetes (Kapsule) a change in where things are hosted, not an app rewrite.

## Alternatives considered
- **Python (FastAPI) backend:** familiar, but less TypeScript practice. It remains the default choice for individual agents later, if they suit Python better.
- **Next.js full stack:** fewer moving parts, but it blurs the frontend/API boundary we want to learn and deploy separately.

## Consequences
- One language across the app, the tests and the tooling.
- Python can still be used later for agents.
