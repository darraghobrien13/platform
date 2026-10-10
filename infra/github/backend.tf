# Same bucket as bootstrap, separate state key. See infra/bootstrap/backend.tf for the why.
terraform {
  backend "s3" {
    bucket = "darragh-platform-tfstate"
    key    = "github/terraform.tfstate"
    region = "fr-par"

    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }

    use_lockfile = true

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
