locals {
  env = "prod"
}

variable "alert_email" {
  description = "Where Cockpit alerts go. Locally: terraform.tfvars (gitignored). CI: TF_VAR_alert_email from a secret."
  type        = string
  sensitive   = true # repo is public: keep it out of plan output / CI logs
}

# Look up this environment's project by name. (Previously read from bootstrap
# state, but that state holds credentials, so CI must never need to read it.)
# A separate provider alias avoids a cycle: the main provider's project_id
# depends on this lookup.
provider "scaleway" {
  alias  = "lookup"
  region = "fr-par"
}

data "scaleway_account_project" "this" {
  provider = scaleway.lookup
  name     = "platform-${local.env}"
}

locals {
  project_id = data.scaleway_account_project.this.id
}

# Every resource lands in this environment's project by default.
provider "scaleway" {
  region     = "fr-par"
  zone       = "fr-par-1"
  project_id = local.project_id
}

# Written by infra/bootstrap; JSON {user, password}. Base64 per the provider.
data "scaleway_secret_version" "db_credentials" {
  secret_name = "db-credentials"
  project_id  = local.project_id
  revision    = "latest"
}

module "environment" {
  source = "../../modules/environment"

  env            = local.env
  project_id     = local.project_id
  alert_email    = var.alert_email
  db_credentials = jsondecode(base64decode(data.scaleway_secret_version.db_credentials.data))
}

output "web_url" {
  value = module.environment.web_url
}

output "api_url" {
  value = module.environment.api_url
}

output "registry_endpoint" {
  value = module.environment.registry_endpoint
}

output "database_endpoint" {
  value = module.environment.database_endpoint
}

output "namespace_id" {
  description = "Used by the app pipeline to find the containers."
  value       = module.environment.namespace_id
}
