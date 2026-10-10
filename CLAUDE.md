# CLAUDE.md: project memory

A learning cloud platform built end to end: IaC, CI/CD, and a full-stack app, with Claude agents hosted on it later. The owner is learning as we go, so explain the "why" briefly at each step.

## Goals
1. Define all infrastructure as code with open-source tools. No click-ops. Any unavoidable manual step is documented in `docs/runbook.md`.
2. One public GitHub repo with branch protection and secret scanning.
3. CI/CD covering lint, tests, security scans, infra plan/apply, and app build/deploy.
4. A simple full-stack app (frontend, API, Postgres), deployed through the pipeline, with a health check and a working URL.
5. **Later, not now:** host Claude agents. Design for it (secrets, containers, outbound access), but don't build any agent pieces yet.

## Constraints
- Budget under €50/month, aiming for near zero. Dev is "mostly off".
- Solo developer on macOS. Comfortable with code and DevOps theory, knows Python, upskilling in TypeScript.
- No Kubernetes yet, but the design should make it easy to add later.
- Cheapest region. Latency doesn't matter.

## Decisions (see `docs/decisions/`)
| ADR | Decision |
|---|---|
| 0001 | **Scaleway**: Serverless Containers, Serverless SQL (Postgres), Secret Manager, Container Registry, Object Storage, Cockpit. GCP is the runner-up. |
| 0002 | **OpenTofu**, with state in Scaleway Object Storage (S3 backend, `use_lockfile`, versioning). A `bootstrap/` stack uses local state, which is then migrated. |
| 0003 | **Public GitHub repo, GitHub Free.** Ruleset on `main`, environments `dev` and `prod` (prod needs approval), secret scanning and push protection. |
| 0004 | **GitHub Actions** on GitHub-hosted runners. Plan on PR, apply to dev on merge, apply to prod after approval. |
| 0005 | **Scoped, expiring API keys** for CI: one IAM Application per environment, rotated every ≤90 days. A deliberate deviation from OIDC. |
| 0006 | Projects `dev` and `prod` in one Organization. Region `fr-par`. `dev.` and `app.darragh.email`. |
| 0007 | TypeScript end to end (Fastify or Hono API, React + Vite, Drizzle or Kysely, Vitest). Status: proposed. |

## Conventions
- **Never commit** secrets, keys, `*.tfstate*`, `.terraform/`, or `*.tfvars` that contain secrets. The repo is **public**, so mark sensitive values `sensitive = true` and never print them in plans or logs.
- **Ask first** before anything billable, any delete or destroy, or any IAM/permission change. **Always show the `tofu plan` before an apply.**
- Every change goes through a PR. Pin third-party GitHub Actions to commit SHAs.
- Record new significant decisions as ADRs. Mark facts that haven't been confirmed with **(verify)**, and check current prices and limits rather than guessing.
- Each phase starts with a short plan and waits for the owner's approval.
- Update this file at the end of every phase.

## Current state (end of Phase 2, 2026-10-10)
- **GitHub:** public repo `darraghobrien13/platform`.
  - Secret scanning and push protection are on.
  - Ruleset `protect-main` (from `infra/github`): changes go through a PR, CI checks `pre-commit` and `secret-scan` must pass, commits must be signed, no force-push or deletion.
  - Environments `dev` and `prod`: only `main` can deploy; prod needs approval and has no admin bypass.
- **Scaleway** (org `8c384137-afc0-49ec-b83f-6e8c3e21bedf`, region `fr-par`):
  - Projects:

    | Project | ID |
    |---|---|
    | `platform-mgmt` | `3404152e-3f65-4b16-a5de-24a8c1c6d960` |
    | `platform-dev` | `841f6418-589a-4549-9d38-97f035dbf8a3` |
    | `platform-prod` | `1fb17fcd-e4a4-4a25-aba3-99cca161c048` |

  - **State:** bucket `darragh-platform-tfstate`, in mgmt, versioned, with `use_lockfile` locking (tested).
    - State keys: `bootstrap/` and `github/`.
  - **Identities:**
    - The owner is used only for billing and break-glass.
    - Day-to-day work uses IAM user `darragh-admin` (group `platform-admins`), with CLI profile `admin`.
      - Its key's preferred project is `platform-mgmt`.
      - It has **no IAM or billing** permissions; this was verified.
  - **Budget:** €25/month, with email alerts at 20/50/80/100%. These are alerts only; Scaleway has no hard cap.
- **Stacks:**
  - `infra/bootstrap`: break-glass only, using a temporary owner key. **Never run in CI**, because its plan output contains emails.
  - `infra/github`: applied locally with the admin profile and `GITHUB_TOKEN=$(gh auth token)`.
- **Local:** `Brewfile` for tools; `mise.toml` pins OpenTofu 1.13.1, Node 24.21.0, tflint, gitleaks and pre-commit.

## Gotchas learned
- **S3 API scope:** the S3 API only sees buckets in the API key's *preferred Object Storage project*. Any key that touches state needs `platform-mgmt` as its preferred project, or you get `403` on `HeadObject`.
- **IAM tags:** Scaleway IAM tags can't contain `:`. Use `key=value`.
- **IAM policy `project_ids`:** wrap the list in `sort()`. The API returns it sorted, and an unsorted list in code causes a perpetual diff.
- **Shell exports:** `export A=x B=$(cmd)` runs `cmd` before `A` is set. Export `SCW_PROFILE` on its own line first.
- **Safety classifier:** it blocks IAM-mutating test calls, even ones expected to fail. Ask the owner to run those.

## Status
- [x] Phase 0: Discovery
- [x] Phase 1: Decisions (ADRs 0001–0007)
- [x] Phase 2: Foundations
- [ ] Phase 3: Infrastructure as code
- [ ] Phase 4: CI/CD
- [ ] Phase 5: Web app
- [ ] Phase 6: Walkthrough

## Next steps (Phase 3: Infrastructure as code)
Show a short plan first and wait for approval.
- Module layout: `infra/modules/*`, with `infra/envs/{dev,prod}` each using its own state key.
- Per environment:
  - Serverless Containers namespace
  - Serverless SQL Database
  - Secret Manager secrets
  - Container Registry namespace, with an image cleanup policy
  - Cockpit logs and metrics
  - Custom domain records
- DNS: `darragh.email` is registered at **GoDaddy**. Decide whether to move DNS to Scaleway Domains & DNS or Cloudflare, so the records can be managed by OpenTofu.
- Refine the cost estimate before applying anything.
