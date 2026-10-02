output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "alarm_count" {
  value = 8 + length(aws_cloudwatch_metric_alarm.tasks_below_desired) + length(aws_cloudwatch_metric_alarm.service_cpu) + length(aws_cloudwatch_metric_alarm.service_memory)
}
