# ECS Service Auto Scaling: Application Auto Scaling owns desiredCount between min and max.
# Both services ignore desired_count in Terraform, otherwise every apply would undo the scaling.

# Looked up by name (like 04_observability) for the ALB metric dimension below
data "aws_lb" "main" {
  name = "${var.name}-alb"
}

locals {
  autoscaling = {
    backend = {
      service = aws_ecs_service.backend.name
      min     = 1
      # Each task opens its own DB connections and the RDS t4g.micro has few to spare
      # (myecs-rds-connections alarms at 60): raise this only together with the DB size
      max = 4
    }
    frontend = {
      service = aws_ecs_service.frontend.name
      min     = 2 # one task per AZ, so losing an AZ never takes the site down
      max     = 4
    }
  }
}

resource "aws_appautoscaling_target" "service" {
  for_each = local.autoscaling

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${data.terraform_remote_state.ecs.outputs.cluster_name}/${each.value.service}"
  min_capacity       = each.value.min
  max_capacity       = each.value.max
}

# Backend: keep average CPU around 60%. It sits behind Service Connect, not the ALB,
# so there is no per-target request metric for it; CPU is the signal ECS gives us.
resource "aws_appautoscaling_policy" "backend_cpu" {
  name               = "${var.name}-backend-cpu-60"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.service["backend"].service_namespace
  scalable_dimension = aws_appautoscaling_target.service["backend"].scalable_dimension
  resource_id        = aws_appautoscaling_target.service["backend"].resource_id

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_out_cooldown = 60  # add capacity quickly
    scale_in_cooldown  = 300 # remove it slowly, so a short dip doesn't cause flapping
  }
}

# Frontend: nginx serving static files barely uses CPU, so scale on load instead:
# requests per task per minute, as counted by the ALB for this target group.
resource "aws_appautoscaling_policy" "frontend_requests" {
  name               = "${var.name}-frontend-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.service["frontend"].service_namespace
  scalable_dimension = aws_appautoscaling_target.service["frontend"].scalable_dimension
  resource_id        = aws_appautoscaling_target.service["frontend"].resource_id

  target_tracking_scaling_policy_configuration {
    # Starting point (~17 req/s per task), not a measured limit: tune it with a load test
    target_value = 1000

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${data.aws_lb.main.arn_suffix}/${aws_lb_target_group.frontend.arn_suffix}"
    }

    scale_out_cooldown = 60
    scale_in_cooldown  = 300
  }
}
