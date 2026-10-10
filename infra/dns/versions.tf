terraform {
  required_version = "~> 1.13"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.86"
    }
  }
}

provider "scaleway" {
  region     = "fr-par"
  zone       = "fr-par-1"
  project_id = data.terraform_remote_state.bootstrap.outputs.project_ids["mgmt"]
}
