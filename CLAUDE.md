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
| 0008 | **Built-in Scaleway URLs, no custom domain.** Scaleway deletes external domains whose nameservers aren't moved within 14 days. `web` forwards `/api/*` to `api`: one origin, no CORS. |

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
    - State keys: `bootstrap/`, `github/`, `envs/dev/` (`envs/prod/` not yet applied).
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
- **External domains:** Scaleway **deletes an external domain** (and every zone under it) if its nameservers aren't moved to Scaleway within **14 days**. Delegating only a subdomain doesn't count. See ADR 0008.
- **Credential lifetime cap:** the org caps credential lifetime at **1 year**. API keys created with no expiry get one anyway, which caused a perpetual replace diff. Workload keys rotate via `time_rotating`. Owner keys created with "1 day" chosen in the console have come out with a 1-year expiry, so check with `scw iam api-key list`.
- **Serverless SQL permissions:** `ServerlessSQLDatabaseDataReadWrite` gives rows only. `CREATE TABLE` fails with `permission denied for schema public`.
- **Container memory:** Scaleway stores memory in whole decimal MB. Send `floor(MiB*1048576/1e6)*1e6` bytes, or every plan shows a phantom change.
- **Strict PR checks:** after one PR merges, the others need **Update branch** (`gh pr update-branch N`) before they can merge.
- **Deleting state objects:** the `scw` CLI can't delete individual objects. Use any S3 client against `https://s3.fr-par.scw.cloud`. Versioning keeps the old version.
- **S3 API scope:** the S3 API only sees buckets in the API key's *preferred Object Storage project*. Any key that touches state needs `platform-mgmt` as its preferred project, or you get `403` on `HeadObject`.
- **IAM tags:** Scaleway IAM tags can't contain `:`. Use `key=value`.
- **IAM policy `project_ids`:** wrap the list in `sort()`. The API returns it sorted, and an unsorted list in code causes a perpetual diff.
- **Shell exports:** `export A=x B=$(cmd)` runs `cmd` before `A` is set. Export `SCW_PROFILE` on its own line first.
- **Safety classifier:** it blocks IAM-mutating test calls, even ones expected to fail. Ask the owner to run those.

## Status
- [x] Phase 0: Discovery
- [x] Phase 1: Decisions (ADRs 0001–0007)
- [x] Phase 2: Foundations
- [ ] Phase 3: Infrastructure as code (in progress)
- [ ] Phase 4: CI/CD
- [ ] Phase 5: Web app
- [ ] Phase 6: Walkthrough

## Phase 3 progress (updated 2026-11-08, resume here)
**Done and verified:**
- **`infra/bootstrap/workloads.tf`:** IAM apps `app-dev` and `app-prod`.
  - Permission: `ServerlessSQLDatabaseDataReadWrite`, scoped to their own project.
  - Keys rotate every 180 days.
  - Login JSON `{user, password}` is in Secret Manager as `db-credentials` in each environment's project.
- **`infra/envs/dev`:** applied; `tofu plan` shows no changes.
  - `web`: https://platformdevc2a6ec33-web.functions.fnc.fr-par.scw.cloud
  - `api`: https://platformdevc2a6ec33-api.functions.fnc.fr-par.scw.cloud
  - Both run the nginx placeholder image, and cold start is about 4–5s.
  - The database `platform-dev` (Postgres 16.15) accepts connections as `app-dev`.
- **Custom domains removed** (ADR 0008). The `infra/dns` stack and its state are deleted.

**Next: option B, chosen by the owner** (separate migration identity):
1. In `infra/bootstrap/workloads.tf`, add a `migrate-<env>` IAM app per environment.
   - Permission: `ServerlessSQLDatabaseReadWrite`, on its own project.
   - Key rotates the same way as the app keys.
   - Secret: `db-migrate-credentials`.
   - Refactor to a role × environment map, and use **`moved` blocks** so the existing `app-*` resources are renamed in state, not recreated. The plan must show no destroys for `app-*`.
2. Apply needs the bootstrap (owner) profile. The owner's "Bootstrap" key is valid until 2027-10-10. **Delete it after the Phase 4 IAM work.**
3. Test against dev:
   - as `migrate-dev`: `CREATE TABLE` plus insert;
   - as `app-dev`: select, insert and update on that table, while `CREATE TABLE` is still denied;
   - then drop the test table.
   - If `app-dev` can't use tables the migrator created, fall back to **option A**: give the app identity `ReadWrite` and run migrations at app startup.

**Remaining in Phase 3:**
- Plan and apply `infra/envs/prod` with the owner's approval, then verify it.
- Write ADR 0009 (identity plane split: workload and migration identities in bootstrap; no private network because Serverless SQL is public with TLS and IAM; secrets live in state in the private bucket).
- Runbook: database smoke test, workload key rotation, viewing logs in Cockpit, and **rotating the admin key, which expires 2026-12-31**.
- Have the owner check actual cost in the console (admin has no billing access). Then update this file and mark Phase 3 complete.

**Carry into Phase 4:**
- Env plans print `alert_emails` (the Gmail address). Hide it before plans run in public CI logs.
- CI identities (`ci-dev`, `ci-prod`, per ADR 0005) go in bootstrap.

**Owner to-dos:**
- **At GoDaddy**, delete the `cloud` NS records (×2) and the `_scaleway-challenge` TXT record.
- Optional: fix the MX typo (`alt4aspmx…` should be `alt4.aspmx…`), and add DKIM and DMARC records for Workspace mail.
