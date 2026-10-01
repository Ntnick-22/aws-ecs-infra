variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name" {
  type        = string
  description = "Prefix used by all project resources e.g. myecs"
}

variable "github_org" {
  type        = string
  description = "GitHub username or org that owns the repos"
}

variable "github_owner_id" {
  type        = string
  description = "Numeric GitHub account ID (gh api users/<org> --jq .id)"
}

variable "infra_repo" {
  type    = string
  default = "aws-ecs-infra"
}

variable "infra_repo_id" {
  type        = string
  description = "Numeric repo ID (gh api repos/<org>/<repo> --jq .id)"
}

variable "app_repos" {
  type    = list(string)
  default = ["my-ecs-frontend", "my-ecs-backend"]
}
