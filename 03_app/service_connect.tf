# Shared namespace for Service Connect: services in it can call each other by short name (e.g. http://backend:8000)
resource "aws_service_discovery_http_namespace" "main" {
  name = var.name
}
