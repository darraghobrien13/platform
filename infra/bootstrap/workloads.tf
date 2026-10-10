# --- Workload identities (one per environment) -------------------------------
# Serverless SQL has no passwords: apps connect AS an IAM application, using its
# API key secret as the DB password. Creating IAM applications needs IAM rights,
# which the day-to-day admin deliberately lacks, so identities live here
# (break-glass) and workloads (infra/envs/*) only READ the resulting secret.
locals {
  workload_envs = toset(["dev", "prod"])
}

resource "scaleway_iam_application" "workload" {
  for_each    = local.workload_envs
  name        = "app-${each.key}"
  description = "Runtime identity for the ${each.key} app: database access only."
  tags        = ["managed-by=opentofu", "env=${each.key}"]
}

resource "scaleway_iam_policy" "workload" {
  for_each       = local.workload_envs
  name           = "app-${each.key}"
  description    = "app-${each.key}: Serverless SQL data access in its own project only."
  application_id = scaleway_iam_application.workload[each.key].id

  rule {
    project_ids          = [scaleway_account_project.this[each.key].id]
    permission_set_names = ["ServerlessSQLDatabaseDataReadWrite"] # data plane only: connect + SQL, not manage DBs
  }
}

# Keys rotate every 180 days: the first bootstrap apply after the rotation date
# replaces the key + secret version; then re-apply envs/* so containers pick it up.
# Each key expires 30 days AFTER its rotation date as a grace period. (The org
# also caps credential lifetime at 1 year, so "never expires" isn't an option.)
resource "time_rotating" "workload_key" {
  for_each      = local.workload_envs
  rotation_days = 180
}

resource "scaleway_iam_api_key" "workload" {
  for_each           = local.workload_envs
  application_id     = scaleway_iam_application.workload[each.key].id
  description        = "app-${each.key} runtime key (Serverless SQL password)"
  default_project_id = scaleway_account_project.this[each.key].id
  expires_at         = timeadd(time_rotating.workload_key[each.key].rotation_rfc3339, "720h")

  lifecycle {
    replace_triggered_by = [time_rotating.workload_key[each.key]]
  }
}

# Hand the credentials to the environment via Secret Manager in ITS project.
resource "scaleway_secret" "db_credentials" {
  for_each    = local.workload_envs
  name        = "db-credentials"
  description = "Serverless SQL login for app-${each.key}: {user, password}. Managed by infra/bootstrap."
  project_id  = scaleway_account_project.this[each.key].id
  tags        = ["managed-by=opentofu"]
}

resource "scaleway_secret_version" "db_credentials" {
  for_each    = local.workload_envs
  secret_id   = scaleway_secret.db_credentials[each.key].id
  description = "api key ${scaleway_iam_api_key.workload[each.key].access_key}"
  data = jsonencode({
    user     = scaleway_iam_application.workload[each.key].id
    password = scaleway_iam_api_key.workload[each.key].secret_key
  })
}
