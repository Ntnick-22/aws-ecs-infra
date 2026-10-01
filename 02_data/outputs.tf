output "db_address" {
  value       = aws_db_instance.main.address
  description = "Hostname only (no port) - use as DB_HOST"
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "db_username" {
  value = aws_db_instance.main.username
}

output "db_secret_arn" {
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
  description = "Secrets Manager secret holding {username, password}"
}
