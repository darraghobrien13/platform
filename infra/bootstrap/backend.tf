# Remote state in Scaleway Object Storage via the S3-compatible API.
# Credentials: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY = your Scaleway API key
# (see docs/runbook.md "Running OpenTofu locally").
terraform {
  backend "s3" {
    bucket = "darragh-platform-tfstate"
    key    = "bootstrap/terraform.tfstate"
    region = "fr-par"

    endpoints = {
      s3 = "https://s3.fr-par.scw.cloud"
    }

    # Native locking: a .tflock object written with S3 conditional writes.
    use_lockfile = true

    # Scaleway is S3-compatible, not AWS: skip AWS-only checks.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
