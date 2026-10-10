# Remote state: same bucket as every stack, own key. See infra/bootstrap/backend.tf.
terraform {
  backend "s3" {
    bucket = "darragh-platform-tfstate"
    key    = "dns/terraform.tfstate"
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
