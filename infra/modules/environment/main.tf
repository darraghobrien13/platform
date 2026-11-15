# One complete environment: registry, database, namespace, web + api services,
# alert contact. infra/envs/<env> just calls this with a few parameters, so dev
# and prod can't drift structurally.
variable "env" {
  description = "Environment name: dev or prod."
  type        = string
}

variable "project_id" {
  type = string
}



variable "db_credentials" {
  description = "{user, password} for Serverless SQL, from Secret Manager."
  type = object({
    user     = string
    password = string
  })
  sensitive = true
}

variable "alert_emails" {
  type = list(string)
}

variable "placeholder_image" {
  description = "Image used until CI deploys the real app (Phase 5)."
  type        = string
  default     = "docker.io/nginxinc/nginx-unprivileged:alpine"
}

variable "max_scale" {
  type    = number
  default = 2
}

variable "db_max_cpu" {
  type    = number
  default = 2
}

locals {
  name = "platform-${var.env}"

  # endpoint looks like postgres://host:5432/db?sslmode=require
  database_url = format("postgres://%s:%s@%s",
    var.db_credentials.user,
    var.db_credentials.password,
    trimprefix(module.database.endpoint, "postgres://"),
  )
}

module "registry" {
  source = "../registry"
  name   = "darragh-${local.name}"
}

module "database" {
  source  = "../database"
  name    = local.name
  max_cpu = var.db_max_cpu
}

resource "scaleway_container_namespace" "this" {
  name        = local.name
  description = "Serverless containers for the ${var.env} environment."
  tags        = ["managed-by=opentofu", "env=${var.env}"]
}

module "api" {
  source          = "../service"
  name            = "api"
  namespace_id    = scaleway_container_namespace.this.id
  image           = var.placeholder_image
  cpu_limit       = 280
  memory_limit_mb = 512
  max_scale       = var.max_scale

  environment_variables = {
    APP_ENV = var.env
  }
  secret_environment_variables = {
    DATABASE_URL = local.database_url
  }
}

module "web" {
  source       = "../service"
  name         = "web"
  namespace_id = scaleway_container_namespace.this.id
  image        = var.placeholder_image
  max_scale    = var.max_scale

  # web serves the frontend AND forwards /api/* to the api container, so the
  # browser only ever talks to one origin: no CORS, and only web needs to know
  # where api lives (avoids a web<->api dependency cycle).
  environment_variables = {
    APP_ENV      = var.env
    API_UPSTREAM = module.api.url
  }
}

# Cockpit: Scaleway product logs/metrics are collected automatically (free at
# default retention). This sets where alerts go.
resource "scaleway_cockpit_alert_manager" "this" {
  project_id = var.project_id

  dynamic "contact_points" {
    for_each = var.alert_emails
    content {
      email = contact_points.value
    }
  }
}

output "web_url" {
  value = module.web.url
}

output "api_url" {
  value = module.api.url
}

output "registry_endpoint" {
  value = module.registry.endpoint
}

output "database_endpoint" {
  description = "No credentials included."
  value       = module.database.endpoint
}

output "namespace_id" {
  value = scaleway_container_namespace.this.id
}
