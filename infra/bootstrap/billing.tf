# --- Budget alerts ------------------------------------------------------------
# Scaleway has no hard spending cap: these only NOTIFY. If one fires, follow
# "Destroy everything" / "Cost spike" in docs/runbook.md.
resource "scaleway_billing_budget" "monthly" {
  consumption_limit = var.monthly_budget_eur
  enabled           = true
}

resource "scaleway_billing_budget_alert" "this" {
  for_each  = toset([for t in var.budget_alert_thresholds : tostring(t)])
  budget_id = scaleway_billing_budget.monthly.id
  threshold = tonumber(each.value)
}

resource "scaleway_billing_budget_alert_notification" "email" {
  for_each        = scaleway_billing_budget_alert.this
  budget_alert_id = each.value.id
  email_addresses = var.alert_emails
}
