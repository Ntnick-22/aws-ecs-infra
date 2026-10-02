variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name" {
  type        = string
  description = "Prefix used by all project resources e.g. myecs"
}

# Not in terraform.tfvars on purpose: the repo is public.
# CI passes it from the ALERT_EMAIL secret; locally: export TF_VAR_alert_email=you@example.com
variable "alert_email" {
  type        = string
  description = "Where alarm notifications are sent"
  sensitive   = true
}

variable "services" {
  type    = set(string)
  default = ["frontend", "backend"]
}
