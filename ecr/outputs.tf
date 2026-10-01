output "ecr_repository_urls" {
  value = { for k, repo in aws_ecr_repository.app : k => repo.repository_url }
}

output "ecr_repository_names" {
  value = { for k, repo in aws_ecr_repository.app : k => repo.name }
}
