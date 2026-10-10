terraform {
  required_version = "~> 1.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

# Token comes from GITHUB_TOKEN (locally: `export GITHUB_TOKEN=$(gh auth token)`).
provider "github" {
  owner = var.owner
}
