output "github_infra_role_arn" {
  value = aws_iam_role.github_actions_infra.arn
}

output "github_app_role_arn" {
  value = aws_iam_role.github_actions_app.arn
}
