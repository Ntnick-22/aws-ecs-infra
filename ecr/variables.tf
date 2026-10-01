variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name" {
  type        = string
  description = "Prefix for repository names e.g. myecs"
}

variable "apps" {
  type    = set(string)
  default = ["frontend", "backend"]
}
