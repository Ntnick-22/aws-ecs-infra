# Looked up by name rather than remote state, so this layer only needs the resources to exist.
# CloudWatch identifies ALB/target-group metrics by their "arn_suffix" (app/<name>/<id>).

data "aws_lb" "main" {
  name = "${var.name}-alb"
}

data "aws_lb_target_group" "frontend" {
  name = "${var.name}-frontend-tg"
}

locals {
  cluster     = var.name
  db_instance = "${var.name}-db"
  alb         = data.aws_lb.main.arn_suffix
  frontend_tg = data.aws_lb_target_group.frontend.arn_suffix
  alarm_topic = [aws_sns_topic.alerts.arn]
}
