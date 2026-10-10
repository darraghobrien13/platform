# platform

A small, fully code-defined cloud platform on [Scaleway](https://www.scaleway.com). It has OpenTofu for infrastructure, GitHub Actions for CI/CD, and a TypeScript full-stack app. It is built as a learning project and designed to host Claude agents later.

- **Why it's built this way:** [`docs/decisions/`](docs/decisions/) (ADRs)
- **How to operate it:** [`docs/runbook.md`](docs/runbook.md)
- **Project memory, conventions and current status:** [`CLAUDE.md`](CLAUDE.md)

## Getting started (macOS, Apple Silicon)

1. **Install Xcode Command Line Tools:** run `xcode-select --install`.
2. **Install Homebrew:** follow the instructions at [brew.sh](https://brew.sh). Then add it, and mise, to your shell:
   ```sh
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
   echo 'eval "$(mise activate zsh)"' >> ~/.zshrc   # after step 3
   ```
3. **Install the tools:** from the repo root, run:
   ```sh
   brew bundle            # system tools: mise, gh, scw, trivy, colima, docker...
   mise trust && mise install   # pinned: opentofu, node, tflint, gitleaks, pre-commit
   pre-commit install     # git hooks: secret scan, fmt, lint
   ```
4. **Start the container runtime** when you need it: `colima start`.

## Repository layout

```
docs/            ADRs and the operations runbook
infra/bootstrap  one-off foundations: projects, state bucket, IAM (run rarely, with a break-glass key)
infra/github     GitHub repo settings as code: ruleset, environments
.github/         CI workflows
```

## Golden rules

- **Never commit secrets or state.** The repo is **public**. The pre-commit hooks and CI both run gitleaks.
- **No click-ops.** The only exceptions are listed in the runbook's "Manual steps" section.
- **Run `tofu plan` before every `tofu apply`, and read the plan.**
