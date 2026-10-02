resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"
}

# AWS emails a confirmation link once; nothing is delivered until it is clicked.
# This layer is not part of the nightly destroy, so the confirmation survives rebuilds.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
