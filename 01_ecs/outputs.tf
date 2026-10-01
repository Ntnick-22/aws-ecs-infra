output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task_role.arn
}

output "acm_validation_cname" {
  value       = aws_acm_certificate.cert.domain_validation_options
  description = "The CNAME records that need to be created in Route 53 for ACM certificate validation."
}

output "https_listener_arn" {
  value = aws_lb_listener.https.arn
}