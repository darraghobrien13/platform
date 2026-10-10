# --- Projects: IAM + billing boundaries --------------------------------------
# mgmt holds shared plumbing (state bucket); dev and prod hold the workloads.
locals {
  projects = {
    mgmt = "Shared plumbing: OpenTofu state"
    dev  = "Development environment"
    prod = "Production environment"
  }
}

resource "scaleway_account_project" "this" {
  for_each    = local.projects
  name        = "platform-${each.key}"
  description = each.value
}

# --- Remote state bucket ------------------------------------------------------
resource "scaleway_object_bucket" "state" {
  name       = var.state_bucket_name
  project_id = scaleway_account_project.this["mgmt"].id

  # Every state write becomes a new version, so a bad apply can be recovered.
  versioning {
    enabled = true
  }

  tags = {
    purpose    = "opentofu-state"
    managed-by = "opentofu"
  }
}

# Private by default; make it explicit.
resource "scaleway_object_bucket_acl" "state" {
  bucket     = scaleway_object_bucket.state.id
  project_id = scaleway_account_project.this["mgmt"].id
  acl        = "private"
}
