# Accepted for now: the AWS-managed key (alias/aws/sns) would silently break delivery, because
# CloudWatch alarms can't publish to a topic encrypted with it. Encrypting needs a customer-managed
# KMS key (~$1/month) whose key policy allows cloudwatch.amazonaws.com. Messages hold alarm names
# and states only.
#trivy:ignore:AWS-0095 Accepted: see above, alarm metadata only; fix needs a customer-managed KMS key
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
