locals {
  frontend_image = "${data.terraform_remote_state.ecr.outputs.ecr_repository_urls["frontend"]}@${data.aws_ecr_image.latest["frontend"].image_digest}"
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.name}-frontend"
  retention_in_days = 7
}

resource "aws_lb_target_group" "frontend" {
  name                 = "${var.name}-frontend-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = data.terraform_remote_state.networking.outputs.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

# Catch-all: overrides the listener's default action (layer-01 demo-app TG).
# Lower priority numbers win, so more specific rules like /whoami (10) still match first.
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = data.terraform_remote_state.ecs.outputs.https_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.name}-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.terraform_remote_state.ecs.outputs.task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.ecs.outputs.task_role_arn
  # Keep old revisions registered: the service may still be running one that CI deployed
  skip_destroy = true

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = local.frontend_image
    essential = true

    portMappings = [{
      name          = "frontend"
      containerPort = 80
      protocol      = "tcp"
      appProtocol   = "http"
    }]

    # Same check ECS-side as the ALB does; nginx:alpine ships busybox wget.
    # 127.0.0.1, not localhost: nginx only listens on IPv4 and "localhost" may resolve to ::1 first
    healthCheck = {
      command     = ["CMD-SHELL", "wget -q -O /dev/null http://127.0.0.1/ || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.frontend.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.name}-frontend"
  cluster         = data.terraform_remote_state.ecs.outputs.cluster_id
  task_definition = aws_ecs_task_definition.frontend.arn
  # 2 tasks: ECS spreads them across the 2 AZs, so losing one task (or one AZ) leaves the ALB a healthy target
  desired_count = 2
  launch_type   = "FARGATE"

  network_configuration {
    subnets          = data.terraform_remote_state.networking.outputs.private_app_subnet_ids
    security_groups  = [data.terraform_remote_state.networking.outputs.frontend_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  # Client-only: no service block, so the frontend can call "backend" but nothing registers as "frontend"
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # CI owns deployments (new task definition revisions); Terraform only creates the service
  lifecycle {
    ignore_changes = [task_definition]
  }

  # nginx resolves "backend" at startup, so the backend must exist in the namespace first
  depends_on = [aws_lb_listener_rule.frontend, aws_ecs_service.backend]
}
