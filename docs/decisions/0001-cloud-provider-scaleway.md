# 0001. Cloud provider: Scaleway

- Status: Accepted
- Date: 2026-10-10

## Context
This is a solo learning platform with a budget under €50/month and a target of near zero. Dev is "mostly off". The platform should prefer managed services and avoid Kubernetes for now, while keeping a K8s path open. It should be able to host Claude agents later, which means containers, secrets and outbound internet access. The owner prefers a budget cloud over a hyperscaler, and has accepted long-lived CI API keys (see [0005](0005-ci-credentials-scoped-api-keys.md)).

## Decision
Use **Scaleway** in a single Organization with separate `dev` and `prod` Projects.

- Compute: **Serverless Containers**, which scale to zero.
- Database: **Serverless SQL Database** (PostgreSQL), which also scales to zero.
- Secrets: **Secret Manager**.
- Container images: **Container Registry**.
- IaC state: **Object Storage**.
- Logs and metrics: **Cockpit**.
- Future Kubernetes: **Kapsule**.

## Alternatives considered
| | Scaleway | GCP (Cloud Run) | Hetzner Cloud | Fly.io |
|---|---|---|---|---|
| Containers | Serverless Containers, scale to zero. Free tier of 200k vCPU-s and 400k GB-s per account per month, then €0.00001/vCPU-s and €0.000002/GB-s | Cloud Run, scale to zero, monthly free tier | VMs only, so Docker runs on the VM | Machines |
| Postgres | Serverless SQL. €0.136/vCPU-h while active, scales to 0 vCPU when idle, storage €0.000272/GB-h (about €0.20/GB-month), 7 days of backups free | Cloud SQL is always on, or use external Neon on its free tier | Self-run on the VM | Managed Postgres from about $38/month |
| Idle cost, dev and prod | About €2–5/month | About €0–2/month | About €4–6/month per VM, billed even when powered off. Prices rose in Apr and Jun 2026 | No free allowance for new orgs |
| CI OIDC federation | None found; federation looks like human SSO only | Yes (Workload Identity Federation) | No | n/a |
| K8s path | Kapsule, with a free shared control plane (verify) | GKE | k3s, self-managed | — |
| Notes | EU-native, simple pricing | Hyperscaler, best IAM | Cheapest raw compute, everything self-run | Ruled out on cost |

- **GCP** is the runner-up. It is slightly cheaper when idle and has proper OIDC. It is the migration target if short-lived CI credentials become a hard requirement again.
- **Hetzner** is excellent value for always-on VMs. It is a poor fit for "mostly off" and managed services.
- **Fly.io** has no free tier, and its managed Postgres alone is close to the whole budget.

## Consequences
- Both environments can stay deployed at about €0 compute, because they scale to zero. "Mostly off" happens automatically, with no daily create and destroy.
- Cold starts are expected on the first request after idle, for both the containers and the database.
- CI uses long-lived scoped API keys. See [0005](0005-ci-credentials-scoped-api-keys.md).
- Scaleway has fewer tutorials than the hyperscalers. We lean on its official docs and the `scaleway/scaleway` OpenTofu provider.
- Agents later run on Serverless Containers or Jobs, with secrets from Secret Manager. Request timeouts and limits are to be checked when we get there.

## Sources
- [Scaleway serverless pricing](https://www.scaleway.com/en/pricing/serverless/)
- [Scaleway Serverless Containers FAQ](https://www.scaleway.com/en/docs/faq/serverless-containers/)
- [Scaleway managed databases pricing](https://www.scaleway.com/en/pricing/managed-databases/)
- [Scaleway Serverless SQL FAQ](https://www.scaleway.com/en/docs/serverless-sql-databases/faq/)
- [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [Hetzner June 2026 price increase](https://privatedevops.com/news/hetzner-june-2026-cloud-price-increase-what-to-do)
- [Fly.io: free Postgres discontinued](https://fly.io/blog/free-postgres.md)
- [Fly.io pricing 2026](https://temps.sh/blog/fly-io-pricing-2026)
- [Neon pricing](https://neon.com/pricing)
