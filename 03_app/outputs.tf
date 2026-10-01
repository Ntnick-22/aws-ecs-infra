output "service_connect_namespace_arn" {
  value = aws_service_discovery_http_namespace.main.arn
}

output "backend_service_name" {
  value = aws_ecs_service.backend.name
}

output "backend_image" {
  value = local.backend_image
}

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}

output "frontend_image" {
  value = local.frontend_image
}
