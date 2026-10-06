variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "name" {
  type        = string
  description = "Prefix for resource names e.g. myecs"
}

variable "db_name" {
  type        = string
  description = "Database created on first boot (letters, digits, underscores only)"
  default     = "myecs"
}

variable "db_username" {
  type    = string
  default = "myecs_user"
}

variable "instance_class" {
  type        = string
  description = "Preferred class. CI overrides it with a fallback (DB_INSTANCE_CLASSES) when AWS has no capacity"
  default     = "db.t4g.micro"
}
