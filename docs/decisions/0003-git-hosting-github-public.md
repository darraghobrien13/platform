# 0003. Git hosting: public GitHub repository on GitHub Free

- Status: Accepted
- Date: 2026-10-10

## Context
The owner works alone and already has a GitHub account. They would prefer a private repo, but not if it costs too much or loses features. The project needs branch protection and an approval step before applying to prod.

GitHub plan limits found in Phase 1:
- **GitHub Free, private repo:** no rulesets or branch protection.
- **GitHub Pro (about $4/month), private repo:** rulesets and environments are available, but environment *required reviewers* on private repos need **Enterprise**.
- **Public repo, any plan:** rulesets, environments with required reviewers, free secret scanning with push protection, and unlimited standard GitHub-hosted Actions minutes.

## Decision
Use a **public repository on GitHub Free**.
- A ruleset on `main` blocks direct pushes, requires a PR, requires CI status checks to pass, and blocks force pushes.
- GitHub Environments `dev` and `prod` are created. `prod` has a required reviewer, which is the owner. Self-review stays allowed, because there is only one person.
- Secret scanning and push protection are enabled.
- SSH keys are used for git authentication. That setup is done in Phase 2.

## Alternatives considered
- **Private + GitHub Pro:** about $4/month for branch protection, but still no deployment approval gate.
- **Private + GitHub Free:** €0, but there is no enforcement at all; it would be an honour system.
- **GitLab.com Free:** private repos with protected branches. Protected-environment approvals need Premium, and the free CI minutes are limited.
- **Codeberg or self-hosted Forgejo:** fully open source, but weaker CI and you run the runners yourself.

## Consequences
Because the repo is public, everything in it and around it is world-readable:
- **Code, Actions logs, and `tofu plan` output are public.** Every sensitive value is marked `sensitive = true`. Plans must never print secrets.
- **Pull requests from forks never receive secrets** (GitHub's default). The repo also requires approval before workflows from outside contributors run.
- **Only GitHub-hosted runners are used.** Self-hosted runners on public repos are a known attack vector.
- Infrastructure names and structure are visible. This is acceptable for a learning project, but it is not a security boundary.
- Moving to a private repo later is a settings change plus a GitHub Pro decision.

## Sources
- [GitHub: about rulesets (plan availability)](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GitHub: managing environments for deployment](https://docs.github.com/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment)
