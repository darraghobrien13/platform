# --- Database identities (role x environment) --------------------------------
# Serverless SQL has no passwords: clients connect AS an IAM application, using
# its API key secret as the DB password. Creating IAM applications needs IAM
# rights, which the day-to-day admin deliberately lacks, so identities live here
# (break-glass) and workloads (infra/envs/*) only READ the resulting secrets.
#
# Two roles per environment (least privilege):
#   app-<env>      the running app: read/write ROWS only, cannot change schema
#   migrate-<env>  the deploy pipeline: runs schema migrations before a release
locals {
  workload_envs = toset(["dev", "prod"])

  db_roles = {
    app = {
      permission_set = "ServerlessSQLDatabaseDataReadWrite" # rows only
      secret_name    = "db-credentials"
      purpose        = "runtime"
    }
    migrate = {
      permission_set = "ServerlessSQLDatabaseReadWrite" # can CREATE/ALTER tables
      secret_name    = "db-migrate-credentials"
      purpose        = "schema migrations"
    }
  }

  # "app-dev" => { role = "app", env = "dev", ... }
  db_identities = {
    for pair in setproduct(keys(local.db_roles), local.workload_envs) :
    "${pair[0]}-${pair[1]}" => merge(local.db_roles[pair[0]], { role = pair[0], env = pair[1] })
  }
}

resource "scaleway_iam_application" "workload" {
  for_each = local.db_identities
  name     = each.key
  # (app-* descriptions kept word-for-word from before the refactor: no churn)
  description = (each.value.role == "app"
    ? "Runtime identity for the ${each.value.env} app: database access only."
  : "Migration identity for ${each.value.env}: used only by the deploy pipeline to change the schema.")
  tags = ["managed-by=opentofu", "env=${each.value.env}", "role=${each.value.role}"]
}

resource "scaleway_iam_policy" "workload" {
  for_each       = local.db_identities
  name           = each.key
  application_id = scaleway_iam_application.workload[each.key].id
  description = (each.value.role == "app"
    ? "${each.key}: Serverless SQL data access in its own project only."
  : "${each.key}: Serverless SQL read/write (incl. schema) in its own project only.")

  rule {
    project_ids          = [scaleway_account_project.this[each.value.env].id]
    permission_set_names = [each.value.permission_set]
  }
}

# Keys rotate every 180 days: the first bootstrap apply after the rotation date
# replaces the key + secret version; then re-apply envs/* so containers pick it up.
# Each key expires 30 days AFTER its rotation date as a grace period. (The org
# also caps credential lifetime at 1 year, so "never expires" isn't an option.)
resource "time_rotating" "workload_key" {
  for_each      = local.db_identities
  rotation_days = 180
}

resource "scaleway_iam_api_key" "workload" {
  for_each           = local.db_identities
  application_id     = scaleway_iam_application.workload[each.key].id
  description        = "${each.key} ${each.value.role == "app" ? "runtime" : "migration"} key (Serverless SQL password)"
  default_project_id = scaleway_account_project.this[each.value.env].id
  expires_at         = timeadd(time_rotating.workload_key[each.key].rotation_rfc3339, "720h")

  lifecycle {
    replace_triggered_by = [time_rotating.workload_key[each.key]]
  }
}

# Hand the credentials to the environment via Secret Manager in ITS project.
resource "scaleway_secret" "db_credentials" {
  for_each    = local.db_identities
  name        = each.value.secret_name
  description = "Serverless SQL login for ${each.key}: {user, password}. Managed by infra/bootstrap."
  project_id  = scaleway_account_project.this[each.value.env].id
  tags        = ["managed-by=opentofu"]
}

resource "scaleway_secret_version" "db_credentials" {
  for_each    = local.db_identities
  secret_id   = scaleway_secret.db_credentials[each.key].id
  description = "api key ${scaleway_iam_api_key.workload[each.key].access_key}"
  data = jsonencode({
    user     = scaleway_iam_application.workload[each.key].id
    password = scaleway_iam_api_key.workload[each.key].secret_key
  })
}

# --- Refactor bookkeeping ------------------------------------------------------
# Instances used to be keyed by env ("dev"); now by identity ("app-dev").
# `moved` tells OpenTofu these are the SAME objects, so it renames them in state
# instead of destroying and recreating live credentials. Safe to delete once
# applied everywhere (kept a while for the record).
moved {
  from = scaleway_iam_application.workload["dev"]
  to   = scaleway_iam_application.workload["app-dev"]
}
moved {
  from = scaleway_iam_application.workload["prod"]
  to   = scaleway_iam_application.workload["app-prod"]
}
moved {
  from = scaleway_iam_policy.workload["dev"]
  to   = scaleway_iam_policy.workload["app-dev"]
}
moved {
  from = scaleway_iam_policy.workload["prod"]
  to   = scaleway_iam_policy.workload["app-prod"]
}
moved {
  from = time_rotating.workload_key["dev"]
  to   = time_rotating.workload_key["app-dev"]
}
moved {
  from = time_rotating.workload_key["prod"]
  to   = time_rotating.workload_key["app-prod"]
}
moved {
  from = scaleway_iam_api_key.workload["dev"]
  to   = scaleway_iam_api_key.workload["app-dev"]
}
moved {
  from = scaleway_iam_api_key.workload["prod"]
  to   = scaleway_iam_api_key.workload["app-prod"]
}
moved {
  from = scaleway_secret.db_credentials["dev"]
  to   = scaleway_secret.db_credentials["app-dev"]
}
moved {
  from = scaleway_secret.db_credentials["prod"]
  to   = scaleway_secret.db_credentials["app-prod"]
}
moved {
  from = scaleway_secret_version.db_credentials["dev"]
  to   = scaleway_secret_version.db_credentials["app-dev"]
}
moved {
  from = scaleway_secret_version.db_credentials["prod"]
  to   = scaleway_secret_version.db_credentials["app-prod"]
}
