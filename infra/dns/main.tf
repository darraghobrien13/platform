# cloud.darragh.email is delegated from GoDaddy (2 NS records, manual step M6) to
# this Scaleway zone. Everything under cloud.* is then managed as code, while the
# rest of darragh.email (Google Workspace mail, www) stays untouched at GoDaddy.
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket                      = "darragh-platform-tfstate"
    key                         = "bootstrap/terraform.tfstate"
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

resource "scaleway_domain_zone" "cloud" {
  domain    = "darragh.email"
  subdomain = "cloud"
}

output "zone" {
  description = "Zone name; env stacks add records here."
  value       = "${scaleway_domain_zone.cloud.subdomain}.${scaleway_domain_zone.cloud.domain}"
}

output "name_servers" {
  description = "Add these as NS records for 'cloud' at GoDaddy."
  value       = scaleway_domain_zone.cloud.ns
}
