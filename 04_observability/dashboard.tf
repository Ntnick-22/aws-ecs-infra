locals {
  service_names = [for s in sort(tolist(var.services)) : "${var.name}-${s}"]

  # Small helpers so each widget below reads as "what it shows", not JSON plumbing
  widget = {
    width  = 8
    height = 6
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text"
        x    = 0, y = 0, width = 24, height = 2
        properties = {
          markdown = "# ${var.name} — ECS Fargate platform\n**Users** (ALB) → **frontend** (nginx) → Service Connect → **backend** (Flask) → **RDS** (PostgreSQL). Alarms email via SNS `${aws_sns_topic.alerts.name}`."
        }
      },

      # ---- Row 1: what users experience ----
      {
        type = "metric", x = 0, y = 2, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "Requests and errors (ALB)"
          region = var.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb, { label = "Requests" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { label = "App 5xx", color = "#d62728" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { label = "ALB 5xx", color = "#ff7f0e" }],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 2, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "Response time (ALB)"
          region = var.region
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb, { stat = "p50", label = "p50" }],
            ["...", { stat = "p95", label = "p95" }],
          ]
          yAxis = { left = { label = "seconds", showUnits = false } }
        }
      },
      {
        type = "metric", x = 16, y = 2, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "Frontend targets (ALB health check)"
          region = var.region
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", local.frontend_tg, "LoadBalancer", local.alb, { label = "Healthy", color = "#2ca02c" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { label = "Unhealthy", color = "#d62728" }],
          ]
        }
      },

      # ---- Row 2: ECS services ----
      {
        type = "metric", x = 0, y = 8, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "Running vs desired tasks"
          region = var.region
          stat   = "Average"
          period = 60
          metrics = flatten([for svc in local.service_names : [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", local.cluster, "ServiceName", svc, { label = "${svc} running" }],
            [".", "DesiredTaskCount", ".", ".", ".", ".", { label = "${svc} desired" }],
          ]])
        }
      },
      {
        type = "metric", x = 8, y = 8, width = local.widget.width, height = local.widget.height
        properties = {
          title   = "Service CPU %"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [for svc in local.service_names : ["AWS/ECS", "CPUUtilization", "ClusterName", local.cluster, "ServiceName", svc, { label = svc }]]
          yAxis   = { left = { min = 0, max = 100 } }
        }
      },
      {
        type = "metric", x = 16, y = 8, width = local.widget.width, height = local.widget.height
        properties = {
          title   = "Service memory %"
          region  = var.region
          stat    = "Average"
          period  = 60
          metrics = [for svc in local.service_names : ["AWS/ECS", "MemoryUtilization", "ClusterName", local.cluster, "ServiceName", svc, { label = svc }]]
          yAxis   = { left = { min = 0, max = 100 } }
        }
      },

      # ---- Row 3: database ----
      {
        type = "metric", x = 0, y = 14, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "Backend: database unavailable (from logs)"
          region = var.region
          stat   = "Sum"
          period = 60
          metrics = [
            ["MyECS/Backend", "DatabaseUnavailable", { label = "Failed DB requests", color = "#d62728" }],
          ]
        }
      },
      {
        type = "metric", x = 8, y = 14, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "RDS CPU % and connections"
          region = var.region
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.db_instance, { stat = "Average", label = "CPU %" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Maximum", label = "Connections", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 16, y = 14, width = local.widget.width, height = local.widget.height
        properties = {
          title  = "RDS free storage (GiB)"
          region = var.region
          period = 300
          metrics = [
            [{ expression = "storage / 1073741824", label = "Free GiB", id = "gib" }],
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", local.db_instance, { stat = "Minimum", id = "storage", visible = false }],
          ]
        }
      },

      # ---- Row 4: every alarm at a glance ----
      {
        type = "alarm", x = 0, y = 20, width = 24, height = 4
        properties = {
          title = "Alarms"
          alarms = concat(
            [
              aws_cloudwatch_metric_alarm.alb_5xx.arn,
              aws_cloudwatch_metric_alarm.target_5xx.arn,
              aws_cloudwatch_metric_alarm.frontend_unhealthy.arn,
              aws_cloudwatch_metric_alarm.slow_responses.arn,
              aws_cloudwatch_metric_alarm.db_unavailable.arn,
              aws_cloudwatch_metric_alarm.rds_cpu.arn,
              aws_cloudwatch_metric_alarm.rds_storage.arn,
              aws_cloudwatch_metric_alarm.rds_connections.arn,
            ],
            [for a in aws_cloudwatch_metric_alarm.tasks_below_desired : a.arn],
            [for a in aws_cloudwatch_metric_alarm.service_cpu : a.arn],
            [for a in aws_cloudwatch_metric_alarm.service_memory : a.arn],
          )
        }
      },
    ]
  })
}
