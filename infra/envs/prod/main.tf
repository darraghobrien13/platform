locals {
  env = "prod"
}

variable "alert_emails" {
  description = "Where Cockpit alerts go. Set in terraform.tfvars (gitignored) or TF_VAR_alert_emails."
  type        = list(string)
}

# Shared lookups: project IDs (bootstrap) and the DNS zone (dns).
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config  = merge(local.state_backend, { key = "bootstrap/terraform.tfstate" })
}

data "terraform_remote_state" "dns" {
  backend = "s3"
  config  = merge(local.state_backend, { key = "dns/terraform.tfstate" })
}

locals {
  state_backend = {
    bucket                      = "darragh-platform-tfstate"
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
  project_id = data.terraform_remote_state.bootstrap.outputs.project_ids[local.env]
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

  env             = local.env
  project_id      = local.project_id
  dns_zone        = data.terraform_remote_state.dns.outputs.zone
  hostname_suffix = ""
  alert_emails    = var.alert_emails
  db_credentials  = jsondecode(base64decode(data.scaleway_secret_version.db_credentials.data))
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
