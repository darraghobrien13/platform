# 0004. CI/CD: GitHub Actions

- Status: Accepted
- Date: 2026-10-10

## Context
We need pipelines that lint, test, scan for security issues, plan and apply infrastructure, and build and deploy the app. The preference is to use the Git host's built-in CI unless there is a good reason not to.

## Decision
Use **GitHub Actions** on GitHub-hosted runners.

**Infrastructure pipeline**
1. **On every PR:** `tofu fmt -check`, `tofu validate`, tflint, an IaC security scan (Trivy or Checkov), and secret scanning (gitleaks). Then `tofu plan` for dev and prod, with the plan summary posted to the PR.
2. **On merge to `main`:** `tofu apply` to **dev** automatically.
3. **Then:** `tofu apply` to **prod** waits for the `prod` environment's required reviewer to approve.

**App pipeline**
1. **On PR:** lint, type-check, unit tests, and a dependency/image scan.
2. **On merge:** build the image (tagged with the git SHA) and push it to Scaleway Container Registry. Deploy to dev, then deploy to prod after approval.
3. **Rollback:** redeploy a previous SHA-tagged image.

## Alternatives considered
- **GitLab CI:** excellent, but it means moving git hosting, and free minutes are limited.
- **Woodpecker CI or Forgejo Actions (open source):** we would host and patch our own runner and server. That adds cost and ops work without teaching anything this project needs right now.
- **Scaleway-native CI:** none comparable exists.

## Consequences
- Public repo, so standard runner minutes are unlimited.
- Third-party actions are pinned to commit SHAs to reduce supply-chain risk.
- Cloud credentials come from GitHub *environment* secrets. See [0005](0005-ci-credentials-scoped-api-keys.md).
- Workflows are code too. Changes to them go through PRs like everything else.

## Sources
- [GitHub: managing environments for deployment](https://docs.github.com/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment)
