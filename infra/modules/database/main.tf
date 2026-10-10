# Serverless SQL (PostgreSQL). min_cpu = 0 means it scales to zero when idle:
# compute is billed only while active (min 5-minute windows); storage always.
variable "name" {
  type = string
}

variable "max_cpu" {
  description = "Upper bound on vCPUs (caps worst-case cost)."
  type        = number
  default     = 2
}

variable "postgres_version" {
  type    = string
  default = "16"
}

resource "scaleway_sdb_sql_database" "this" {
  name    = var.name
  min_cpu = 0
  max_cpu = var.max_cpu
  version = var.postgres_version
}

output "endpoint" {
  description = "postgres://host:port/db?sslmode=require (no credentials)."
  value       = scaleway_sdb_sql_database.this.endpoint
}

output "id" {
  value = scaleway_sdb_sql_database.this.id
}
