# --- CI identities (ADR 0005, revised in ADR 0010) ----------------------------
# GitHub only releases environment secrets to jobs on `main`, so PR plans can't
# use the apply keys -- and shouldn't. Split by capability:
#   ci-plan  READ-ONLY on dev+prod; used by `tofu plan -lock=false` on PRs
#   ci-dev   changes dev only;  used on main, GitHub environment `dev`
#   ci-prod  changes prod only; used on main after approval, environment `prod`
#            (+ read on the dev registry, to promote the exact image dev ran)
locals {
  ci_read_sets = [
    "ContainersReadOnly",
    "ContainerRegistryReadOnly",
    "ServerlessSQLDatabaseReadOnly",
    "SecretManagerReadOnly",
    "SecretManagerSecretAccess", # plan builds DATABASE_URL from the db-credentials secret
    "ObservabilityReadOnly",
  ]
  ci_write_sets = [
    "ContainersFullAccess",
    "ContainerRegistryFullAccess",
    "ServerlessSQLDatabaseFullAccess",
    "SecretManagerReadOnly",
    "SecretManagerSecretAccess", # DATABASE_URL + migrate credentials for the deploy job
    "ObservabilityFullAccess",
  ]

  ci_identities = {
    ci-plan = { desc = "CI: read-only plans on pull requests (dev + prod).", envs = ["dev", "prod"], sets = local.ci_read_sets, state_write = false }
    ci-dev  = { desc = "CI: apply + deploy to dev (GitHub environment dev).", envs = ["dev"], sets = local.ci_write_sets, state_write = true }
    ci-prod = { desc = "CI: apply + deploy to prod (GitHub environment prod, approval required).", envs = ["prod"], sets = local.ci_write_sets, state_write = true }
  }
}

resource "scaleway_iam_application" "ci" {
  for_each    = local.ci_identities
  name        = each.key
  description = each.value.desc
  tags        = ["managed-by=opentofu", "role=ci"]
}

resource "scaleway_iam_policy" "ci" {
  for_each       = local.ci_identities
  name           = each.key
  description    = each.value.desc
  application_id = scaleway_iam_application.ci[each.key].id

  # Its environment project(s): the product rights it needs.
  rule {
    project_ids          = sort([for e in each.value.envs : scaleway_account_project.this[e].id])
    permission_set_names = sort(each.value.sets)
  }

  # mgmt project: state objects. The bucket policy below narrows this to the
  # identity's own state prefix.
  rule {
    project_ids = [scaleway_account_project.this["mgmt"].id]
    permission_set_names = sort(each.value.state_write
      ? ["ObjectStorageBucketsRead", "ObjectStorageObjectsRead", "ObjectStorageObjectsWrite", "ObjectStorageObjectsDelete"]
    : ["ObjectStorageBucketsRead", "ObjectStorageObjectsRead"])
  }

  # Look up projects by name (envs/* do this instead of reading bootstrap state).
  rule {
    organization_id      = scaleway_account_project.this["mgmt"].organization_id
    permission_set_names = ["ProjectReadOnly"]
  }

  # Promotion: prod copies the image dev already tested from the dev registry.
  dynamic "rule" {
    for_each = each.key == "ci-prod" ? [1] : []
    content {
      project_ids          = [scaleway_account_project.this["dev"].id]
      permission_set_names = ["ContainerRegistryReadOnly"]
    }
  }
}

# ADR 0005: CI keys rotate at most every 90 days. After rotation, push the new
# key to GitHub (runbook: "Rotate CI keys").
resource "time_rotating" "ci_key" {
  for_each      = local.ci_identities
  rotation_days = 90
}

resource "scaleway_iam_api_key" "ci" {
  for_each       = local.ci_identities
  application_id = scaleway_iam_application.ci[each.key].id
  description    = "${each.key} GitHub Actions key"
  # mgmt: the S3 API only sees buckets in the key's preferred project (state lives there).
  default_project_id = scaleway_account_project.this["mgmt"].id
  expires_at         = timeadd(time_rotating.ci_key[each.key].rotation_rfc3339, "336h") # +14 days grace

  lifecycle {
    replace_triggered_by = [time_rotating.ci_key[each.key]]
  }
}

output "ci_keys" {
  description = "Pipe into `gh secret set`; never print. See runbook."
  sensitive   = true
  value = { for k, v in scaleway_iam_api_key.ci : k => {
    access_key = v.access_key
    secret_key = v.secret_key
  } }
}

# --- State bucket policy -------------------------------------------------------
# Once a bucket has a policy, ONLY principals listed here can use it (the owner
# can always edit the policy, so a mistake is recoverable with break-glass).
data "scaleway_iam_user" "owner" {
  email = var.owner_email
}

locals {
  state_bucket = scaleway_object_bucket.state.name
  ci_state_prefixes = {
    ci-plan = "envs/*"
    ci-dev  = "envs/dev/*"
    ci-prod = "envs/prod/*"
  }
}

resource "scaleway_object_bucket_policy" "state" {
  bucket     = scaleway_object_bucket.state.name
  project_id = scaleway_account_project.this["mgmt"].id

  policy = jsonencode({
    Version = "2023-04-17"
    Id      = "tfstate-access"
    Statement = concat(
      [
        {
          Sid    = "humans-full-access"
          Effect = "Allow"
          Principal = { SCW = [
            "user_id:${data.scaleway_iam_user.owner.id}",
            "user_id:${scaleway_iam_user.admin.id}",
          ] }
          Action   = ["s3:*"]
          Resource = [local.state_bucket, "${local.state_bucket}/*"]
        },
      ],
      [for k, prefix in local.ci_state_prefixes : {
        Sid       = "${k}-list"
        Effect    = "Allow"
        Principal = { SCW = "application_id:${scaleway_iam_application.ci[k].id}" }
        Action    = ["s3:ListBucket"]
        Resource  = [local.state_bucket]
      }],
      [for k, prefix in local.ci_state_prefixes : {
        Sid       = "${k}-objects"
        Effect    = "Allow"
        Principal = { SCW = "application_id:${scaleway_iam_application.ci[k].id}" }
        Action = local.ci_identities[k].state_write ? [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        ] : ["s3:GetObject"]
        Resource = ["${local.state_bucket}/${prefix}"]
      }],
    )
  })
}
