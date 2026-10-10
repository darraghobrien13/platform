# Architecture Decision Records

Each significant decision gets a short ADR, so a future reader, human or Claude, can see **what** was decided and **why**. A superseded ADR is never deleted. Instead, its status changes to `Superseded by NNNN`.

| # | Decision | Status |
|---|---|---|
| [0001](0001-cloud-provider-scaleway.md) | Cloud provider: Scaleway | Accepted |
| [0002](0002-iac-opentofu.md) | IaC: OpenTofu with remote state in Scaleway Object Storage | Accepted |
| [0003](0003-git-hosting-github-public.md) | Git hosting: public GitHub repo, GitHub Free | Accepted |
| [0004](0004-cicd-github-actions.md) | CI/CD: GitHub Actions | Accepted |
| [0005](0005-ci-credentials-scoped-api-keys.md) | CI credentials: scoped, expiring API keys (no OIDC yet) | Accepted |
| [0006](0006-environments-region-dns.md) | Environments, region and DNS | Accepted |
| [0007](0007-app-stack-typescript.md) | App stack: TypeScript end to end | Proposed |

Figures marked **(verify)** were not confirmed from a primary source during Phase 1. They are re-checked in Phase 2.

## Template

```markdown
# NNNN. Title

- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD

## Context
What problem or constraint forces a decision?

## Decision
What we chose.

## Alternatives considered
What else we looked at and why it lost.

## Consequences
What becomes easier, what becomes harder, what we must now watch.

## Sources
Links used to justify facts and prices.
```
