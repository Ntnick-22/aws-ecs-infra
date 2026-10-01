variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type = string
}

variable "domain_name" {
  type        = string
  description = "Domain for ACM certificate e.g. myecs.nt-nick.link"
}
