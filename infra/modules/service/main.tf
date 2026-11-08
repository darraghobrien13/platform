# One public HTTP service: a Serverless Container on Scaleway's built-in HTTPS URL.
# (Custom domains were removed: see ADR 0008.)
variable "name" {
  type = string
}

variable "namespace_id" {
  type = string
}

variable "image" {
  description = "Initial image only. CI owns the image after creation (see lifecycle)."
  type        = string
}

variable "port" {
  type    = number
  default = 8080
}

variable "cpu_limit" {
  description = "mvCPU. Scaleway pairs CPU/memory: 140/256MB, 280/512MB, 560/1024MB..."
  type        = number
  default     = 140
}

variable "memory_limit_mb" {
  description = "Memory in MiB (256, 512, ...)."
  type        = number
  default     = 256
}

variable "max_scale" {
  description = "Max instances: a cost ceiling as much as a capacity setting."
  type        = number
  default     = 2
}

variable "health_path" {
  description = "HTTP liveness path. Must NOT touch the database (would keep it awake and billing)."
  type        = string
  default     = "/"
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "secret_environment_variables" {
  type      = map(string)
  default   = {}
  sensitive = true
}



resource "scaleway_container" "this" {
  name         = var.name
  namespace_id = var.namespace_id
  image        = var.image
  port         = var.port

  cpu_limit = var.cpu_limit
  # Scaleway stores memory in whole decimal MB (e.g. 512 MiB -> 536000000 bytes).
  # Send exactly that, or every plan shows a phantom memory change.
  memory_limit_bytes = floor(var.memory_limit_mb * 1048576 / 1000000) * 1000000
  min_scale          = 0 # scale to zero when idle: pay nothing
  max_scale          = var.max_scale

  privacy                = "public"
  protocol               = "http1"
  https_connections_only = true

  environment_variables        = var.environment_variables
  secret_environment_variables = var.secret_environment_variables

  liveness_probe {
    http {
      path = var.health_path
    }
    failure_threshold = 3
    interval          = "30s"
    timeout           = "5s"
  }

  lifecycle {
    # After creation, CI deploys new images; don't let tofu roll them back.
    ignore_changes = [image, registry_sha256]
  }
}

output "url" {
  value = scaleway_container.this.public_endpoint
}

output "id" {
  value = scaleway_container.this.id
}
