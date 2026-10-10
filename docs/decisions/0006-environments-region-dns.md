# 0006. Environments, region and DNS

- Status: Accepted
- Date: 2026-10-10

## Context
The budget is under €50/month, and the region should be the cheapest available. Latency doesn't matter much. The owner holds `darragh.email`. Separate dev and prod environments are wanted if the budget allows.

## Decision
- **Environments:** two Scaleway **Projects** in one Organization, `dev` and `prod`.
  - Projects are free and form an IAM and billing boundary.
  - Both stay deployed, because the services scale to zero when idle (see [0001](0001-cloud-provider-scaleway.md)).
  - Each environment has its own OpenTofu state and its own CI identity.
- **Region:** `fr-par` (Paris). Serverless pricing appears to be the same across Scaleway regions, and Paris has the widest service availability (verify per service in Phase 2).
  - The region is a single variable, so moving later is a variable change plus a data migration.
- **DNS:** `dev.darragh.email` points to dev and `app.darragh.email` points to prod. These are custom domains on Serverless Containers, with managed TLS.
  - *Where* the DNS zone is hosted (Scaleway Domains & DNS vs Cloudflare free) depends on where the domain is registered, which is decided in Phase 2.
  - Whichever is chosen, the records are managed in OpenTofu.
  - The provider-generated URLs remain a fallback.

## Alternatives considered
- **A single environment:** cheaper by about €1, but there is nowhere to test infrastructure changes safely.
- **A separate Organization per environment:** stronger isolation, but more account overhead than a solo project needs.
- **`nl-ams` or `pl-waw`:** fine options; there was no price reason to prefer them.

## Consequences
- A fixed cost for two environments: database storage, secret versions, and registry and state storage. The estimate is €2–5/month total (refined in Phase 3).
- Prod and dev must never share credentials, state, or databases.
