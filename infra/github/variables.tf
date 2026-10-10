variable "owner" {
  description = "GitHub account that owns the repo."
  type        = string
  default     = "darraghobrien13"
}

variable "repository" {
  description = "Repository name."
  type        = string
  default     = "platform"
}

variable "required_checks" {
  description = "CI job names that must pass before merging to main."
  type        = list(string)
  default     = ["pre-commit", "secret-scan"]
}
