output "project_ids" {
  description = "Project IDs, keyed by environment."
  value       = { for k, p in scaleway_account_project.this : k => p.id }
}

output "organization_id" {
  value = scaleway_account_project.this["mgmt"].organization_id
}

output "state_bucket" {
  value = scaleway_object_bucket.state.name
}

output "s3_endpoint" {
  value = "https://s3.${var.region}.scw.cloud"
}
