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

## Status
- [x] Phase 0: Discovery
- [x] Phase 1: Decisions (ADRs 0001–0007), awaiting owner review
- [ ] Phase 2: Foundations
- [ ] Phase 3: Infrastructure as code
- [ ] Phase 4: CI/CD
- [ ] Phase 5: Web app
- [ ] Phase 6: Walkthrough

## Next steps (Phase 2: Foundations)
- Install local tooling: OpenTofu, the Scaleway CLI, gh, gitleaks, tflint, pre-commit, Node LTS, Docker or another container runtime.
- Run `git init`, add `.gitignore` and a pre-commit secret scan, create the public GitHub repo, set up SSH auth, add the ruleset, and enable secret scanning.
- Create the Scaleway account and harden it: MFA, no day-to-day use of the Organization owner, least-privilege identities. Create the `dev` and `prod` Projects.
- Set up billing alerts. Check whether Scaleway offers a **hard** spending cap or only alerts.
- Bootstrap the state bucket and prove `use_lockfile` locking works with two concurrent plans.
- Open checks:
  - Container Registry and Cockpit free allowances.
  - Whether the Kapsule control plane is free.
  - Where `darragh.email` is registered.
  - The exact OpenTofu version to pin.
