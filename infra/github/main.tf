data "github_user" "owner" {
  username = var.owner
}

locals {
  # App ID of GitHub Actions: pins required checks to Actions so nothing else
  # can satisfy them by posting a status with the same name.
  github_actions_app_id = 15368
}

# --- Protect main -------------------------------------------------------------
# Solo-dev setup: every change goes through a PR with green CI, but no human
# approval is required (you can't approve your own PR on GitHub).
resource "github_repository_ruleset" "main" {
  name        = "protect-main"
  repository  = var.repository
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion            = true # main can't be deleted
    non_fast_forward    = true # no force-pushes / history rewrites
    required_signatures = true # every commit on main is Verified

    pull_request {
      required_approving_review_count   = 0
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = false
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true # branch must be up to date with main

      dynamic "required_check" {
        for_each = var.required_checks
        content {
          context        = required_check.value
          integration_id = local.github_actions_app_id
        }
      }
    }
  }
}

# --- Deployment environments ---------------------------------------------------
# Jobs that deploy declare `environment: dev|prod`; secrets are scoped per environment.
resource "github_repository_environment" "dev" {
  repository  = var.repository
  environment = "dev"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "prod" {
  repository  = var.repository
  environment = "prod"

  # The approval gate: prod jobs pause until you click "Approve".
  # Self-review stays allowed because you're the only reviewer.
  prevent_self_review = false
  can_admins_bypass   = false # repo admins (you) can't skip the gate either
  reviewers {
    users = [data.github_user.owner.id]
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

# Only main may deploy to either environment.
resource "github_repository_environment_deployment_policy" "main_only" {
  for_each = {
    dev  = github_repository_environment.dev.environment
    prod = github_repository_environment.prod.environment
  }

  repository     = var.repository
  environment    = each.value
  branch_pattern = "main"
}
