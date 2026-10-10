# 0005. CI credentials: scoped, expiring Scaleway API keys

- Status: Accepted (deliberate deviation from the original goal)
- Date: 2026-10-10

## Context
The original goal was for CI to authenticate with short-lived credentials via OIDC or workload identity, with no long-lived keys. In Phase 1 we found no Scaleway feature that lets GitHub Actions swap its OIDC token for cloud credentials. Scaleway's identity federation appears to be for human SSO only. The owner explicitly accepted long-lived keys for now.

## Decision
Use long-lived API keys, but keep each one small, short-lived and separated:
- **One IAM Application per environment:** `ci-dev` and `ci-prod`. These are machine identities, not human users.
- **Least privilege:** each application's policy grants only the permission sets needed. It is scoped to **its own Project** and cannot touch the other environment. The state bucket is reachable only under that environment's own state path.
- **Expiry:** every API key gets an expiration date, at most 90 days. Rotation is a runbook procedure.
- **Storage:** keys live as GitHub **environment** secrets in `dev` and `prod`. Repository-wide secrets are not used. The prod key is only released to jobs approved for the `prod` environment.
- **No human uses CI keys**, and CI never uses a human's or the Organization owner's credentials.

## Alternatives considered
- **Move to GCP for Workload Identity Federation.** Rejected for now. See [0001](0001-cloud-provider-scaleway.md).
- **A token broker or vault that mints short-lived keys.** Rejected for now: it is overkill for a solo learning setup, and needs something always running.

## Consequences
- A leaked key is valid until it expires or is revoked. It is limited to one environment and its permissions.
- Rotation is manual. It will be documented in `docs/runbook.md`, and a calendar reminder covers it.
- **Revisit when:** Scaleway ships CI/OIDC federation, we migrate providers, or agents start handling sensitive data.

## Sources
- [Scaleway IAM docs](https://www.scaleway.com/en/docs/iam/). Checked for CI federation: only human SSO and identity provisioning are documented.
