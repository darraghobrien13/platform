# 0007. App stack: TypeScript end to end

- Status: Proposed (finalised in Phase 5)
- Date: 2026-10-10

## Context
We need a simple full-stack app with a frontend, an API, and Postgres. The owner knows Python and wants to improve at TypeScript. The platform will later host Claude agents, and both Python and TypeScript have first-class Anthropic SDKs.

## Decision (proposed)
- **API:** Node.js + TypeScript, with Fastify or Hono (choice in Phase 5).
- **Frontend:** React + Vite + TypeScript.
- **Database access:** a type-safe TypeScript query builder or ORM, such as Drizzle or Kysely, plus versioned migrations.
- **Tests:** Vitest for unit tests, and an API integration test against a real Postgres in CI.
- **Packaging:** one OCI image per service, built in CI and tagged with the git SHA.
  - Config comes from environment variables, and secrets are injected at runtime from Secret Manager.
  - Every service exposes `/healthz`.
  - These conventions keep a future move to Kubernetes (Kapsule) a change in where things are hosted, not an app rewrite.

## Alternatives considered
- **Python (FastAPI) backend:** familiar, but less TypeScript practice. It remains the default choice for individual agents later, if they suit Python better.
- **Next.js full stack:** fewer moving parts, but it blurs the frontend/API boundary we want to learn and deploy separately.

## Consequences
- One language across the app, the tests and the tooling.
- Python can still be used later for agents.
