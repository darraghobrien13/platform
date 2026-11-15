# 0010. Pipeline design: plan/apply identity split, build once and promote

- Status: Accepted
- Date: 2026-11-15
- Amends: [0005](0005-ci-credentials-scoped-api-keys.md)

## Context
- GitHub releases **environment** secrets (`dev`, `prod`) only to jobs on `main` (our deployment branch policy), and `prod` only after approval. A plan running on a PR branch therefore can't use the apply keys, and it shouldn't hold them anyway.
- The repo is public, so logs, job summaries and artifacts are world-readable.

## Decision
**CI identities** live in `infra/bootstrap/ci.tf` and are created with break-glass. Keys rotate every 90 days, with 14 days' grace.

| Identity | Rights | GitHub secret | Used by |
|---|---|---|---|
| `ci-plan` | Read-only on dev and prod. Reads the env state files. Reads secrets, because the plan builds `DATABASE_URL`. | Repository `SCW_PLAN_*` | `tofu plan -lock=false` on PRs |
| `ci-dev` | Changes dev only. Writes `envs/dev/*` state. | Environment `dev`: `SCW_*` | Apply and deploy to dev |
| `ci-prod` | Changes prod only. Writes `envs/prod/*` state. Can read the **dev registry**. | Environment `prod`: `SCW_*` | Apply and deploy to prod, after approval |

- **State bucket policy:**
  - The owner and `darragh-admin` have full access.
  - Each CI identity can reach only its own state prefix.
  - **No CI identity can read `bootstrap/` or `github/` state**, which holds credentials.
  - All 16 allow/deny cases were tested on 2026-11-15.
- **The env stacks look up their project by name** instead of reading bootstrap state.

**Infrastructure pipeline** (`infra.yml` and the reusable `tofu-apply.yml`):
- **On a PR:** a Trivy IaC scan, and a plan for dev and prod.
- **On `main`:** plan and apply dev, then plan and apply prod after approval.
- The plan file is applied in the same job and **never uploaded**: it contains sensitive values in plain text, and artifacts on a public repo are public.
- `infra/bootstrap` and `infra/github` never run in CI.

**App pipeline** (`app.yml` and the reusable `deploy.yml`):
- **On a PR:** build and Trivy-scan the images.
- **On `main` (dev):** build the images once, scan them, and push them to the dev registry with a 12-character SHA tag. Check the migrate credentials. Deploy `api`, then `web`. Smoke-test `/healthz` for the expected version, both directly and through the web `/api` proxy.
- **Prod (after approval):** copy the **same image** from the dev registry with `crane`, without rebuilding. Then migrate, deploy and smoke-test.
- **Rollback:** "Run workflow" with an environment and a SHA. It redeploys an image that already exists in that environment's registry.
- **Shared concurrency group** `env-<env>`: an infra apply and an app deploy never overlap in the same environment.
- OpenTofu ignores the container `image`, so infra applies never undo a deploy.

## Alternatives considered
- **Plan only after merge, with no plan identity.** Simpler, but you'd see the plan only after merging, and that's the moment a review matters most.
- **Rebuild for prod.** Then prod would run an image that wasn't the one tested in dev.
- **Upload the plan artifact between jobs.** It would be public, and it contains secrets.

## Consequences
- **The prod plan is re-computed** in the apply job after approval. Review it on the PR, and on the run page before approving.
- **`ci-plan` can read database credentials**, because the plan needs them. A leak of the repository-level secret would expose database row access in dev and prod, though not infrastructure control.
- **Rotating CI keys** needs break-glass, plus `gh secret set` (runbook).
