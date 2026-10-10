variable "region" {
  description = "Scaleway region for everything in this platform."
  type        = string
  default     = "fr-par"
}

variable "state_bucket_name" {
  description = "Globally unique name of the bucket holding OpenTofu state."
  type        = string
}

variable "admin_username" {
  description = "Username of the day-to-day admin IAM user."
  type        = string
  default     = "darragh-admin"
}

variable "admin_email" {
  description = "Email for the day-to-day admin IAM user (must differ from the owner's)."
  type        = string
}

variable "alert_emails" {
  description = "Addresses that receive billing alerts."
  type        = list(string)
}

variable "monthly_budget_eur" {
  description = "Monthly budget in EUR. Alerts fire at percentages of this; it is NOT a hard cap."
  type        = number
  default     = 25
}

variable "budget_alert_thresholds" {
  description = "Alert thresholds as % of the monthly budget."
  type        = list(number)
  default     = [20, 50, 80, 100]
}
