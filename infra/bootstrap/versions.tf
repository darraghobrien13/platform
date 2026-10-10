terraform {
  required_version = "~> 1.13"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.86"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # First apply ran with LOCAL state (the bucket didn't exist yet); state was then
  # migrated into the bucket this stack creates. See backend.tf.
}

provider "scaleway" {
  region = var.region
  zone   = "${var.region}-1"
  # Credentials come from the environment / scw profile, never from code.
}
