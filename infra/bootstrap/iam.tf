# --- Day-to-day admin identity -----------------------------------------------
# The owner account is for billing and break-glass only. Daily work uses this
# user, which can run anything INSIDE the platform projects but cannot change
# IAM or billing (so a leaked key can't escalate itself).

# Generated at apply time and never written to state (ephemeral + write-only).
# Scaleway emails it to admin_email; change it on first login and store it in NordPass.
ephemeral "random_password" "admin_initial" {
  length  = 24
  special = true
}

resource "scaleway_iam_user" "admin" {
  email               = var.admin_email
  username            = var.admin_username
  password_wo         = ephemeral.random_password.admin_initial.result
  password_wo_version = 1
  send_password_email = true
  send_welcome_email  = false
  tags                = ["managed-by=opentofu"]
}

resource "scaleway_iam_group" "platform_admins" {
  name        = "platform-admins"
  description = "Full access inside platform projects; no IAM or billing."
  user_ids    = [scaleway_iam_user.admin.id]
  tags        = ["managed-by=opentofu"]
}

resource "scaleway_iam_policy" "platform_admins" {
  name        = "platform-admins"
  description = "Day-to-day admin: all products in mgmt/dev/prod projects, read-only at org level."
  group_id    = scaleway_iam_group.platform_admins.id

  rule {
    # sorted: the API returns IDs sorted, so unsorted config causes a perpetual diff
    project_ids          = sort([for p in scaleway_account_project.this : p.id])
    permission_set_names = ["AllProductsFullAccess"]
  }

  rule {
    organization_id      = scaleway_account_project.this["mgmt"].organization_id
    permission_set_names = ["ProjectReadOnly"]
  }
}
