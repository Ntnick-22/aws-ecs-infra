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

variable "infra_repo" {
  type    = string
  default = "aws-ecs-infra"
}

variable "app_repos" {
  type    = list(string)
  default = ["my-ecs-frontend", "my-ecs-backend"]
}
