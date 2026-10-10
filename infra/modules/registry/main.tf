# Private container registry namespace. Images: rg.<region>.scw.cloud/<name>/<image>:<tag>
variable "name" {
  description = "Registry namespace name (globally unique per region)."
  type        = string
}

resource "scaleway_registry_namespace" "this" {
  name        = var.name
  description = "Container images for ${var.name}. Pushed by CI."
  is_public   = false
}

output "endpoint" {
  value = scaleway_registry_namespace.this.endpoint
}

output "id" {
  value = scaleway_registry_namespace.this.id
}
