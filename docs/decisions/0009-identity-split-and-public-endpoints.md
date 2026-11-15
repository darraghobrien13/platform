# 0009. Identities live in bootstrap; workloads use public endpoints (no private network)

- Status: Accepted
- Date: 2026-11-15

## Context
- Serverless SQL has no username/password logins. A client connects **as an IAM application**, using its API key secret as the password.
- Creating IAM applications needs IAM permissions. The day-to-day `darragh-admin` user deliberately has none, so a leaked admin key can't escalate itself.
- We also needed to decide whether to put the containers and the database on a private network.

## Decision
1. **Identity plane vs. workload plane.**
   - `infra/bootstrap` (break-glass, owner key) creates every machine identity, its policy, its API key, and a Secret Manager secret in the target environment's project.
   - `infra/envs/*` (admin key) only **reads** those secrets.
2. **Two database identities per environment:**
   - `app-<env>` has `ServerlessSQLDatabaseDataReadWrite`: rows only.
   - `migrate-<env>` has `ServerlessSQLDatabaseReadWrite`, which allows schema changes. Only the deploy pipeline uses it.
   - **Tested on both dev and prod:** `app` can do CRUD on tables `migrate` created, but can't CREATE or DROP.
3. **Key rotation:** every API key rotates every 180 days via `time_rotating`, and expires 30 days after its rotation date. The org caps credential lifetime at 1 year anyway.
4. **No private network.**
   - Serverless SQL is reachable only on a public endpoint, protected by TLS (`sslmode=require`) and IAM authentication.
   - The containers are public HTTPS endpoints.
   - A private network would need the always-on Managed Database (about €10+/month), which breaks the near-zero budget.

## Alternatives considered
- **Let the admin user manage IAM:** fewer break-glass sessions, but a leaked admin key could then mint itself full rights.
- **One database identity with `ReadWrite`, and the app migrates at startup:** simpler, but a compromised or buggy app could drop the schema.
- **Managed Database plus a private network:** stronger network isolation, at a cost that doesn't fit this project.

## Consequences
- **Adding an identity is a break-glass operation.** That applies to CI identities in Phase 4, agent identities later, and every 180-day rotation. The procedure is in the runbook.
- **Secrets end up in OpenTofu state** (API key secrets, and the `DATABASE_URL` built in the env stacks).
  - State lives in the private, versioned `darragh-platform-tfstate` bucket. Only the owner and `darragh-admin` can read it, and it's **never** committed.
  - Plans show these values as `(sensitive value)`.
- **Deploy order is fixed:** migrations run first, as `migrate-<env>`, then the new app version starts. The app never migrates.
- **The database is internet-reachable** (but not anonymously). A leaked `app-*` key gives row access until it's revoked or rotated.
- **Later agent work:** agents get their own identities through the same pattern, each with the narrowest permission set that works.
