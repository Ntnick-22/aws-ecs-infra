locals {
  backend_image = "${data.terraform_remote_state.ecr.outputs.ecr_repository_urls["backend"]}@${data.aws_ecr_image.latest["backend"].image_digest}"
  db_secret_arn = data.terraform_remote_state.data.outputs.db_secret_arn
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.name}-backend"
  retention_in_days = 14
}

# AmazonECSTaskExecutionRolePolicy (layer 01) covers ECR + logs, not Secrets Manager
resource "aws_iam_role_policy" "execution_read_db_secret" {
  name = "read-db-secret"
  role = split("/", data.terraform_remote_state.ecs.outputs.task_execution_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [local.db_secret_arn]
    }]
  })
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name}-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.terraform_remote_state.ecs.outputs.task_execution_role_arn
  task_role_arn            = data.terraform_remote_state.ecs.outputs.task_role_arn
  # Keep old revisions registered: the service may still be running one that CI deployed
  skip_destroy = true

  container_definitions = jsonencode([{
    name      = "backend"
    image     = local.backend_image
    essential = true

    portMappings = [{
      name          = "backend" # Service Connect refers to the port by this name
      containerPort = 8000
      protocol      = "tcp"
      appProtocol   = "http"
    }]

    environment = [
      { name = "DB_HOST", value = data.terraform_remote_state.data.outputs.db_address },
      { name = "DB_PORT", value = tostring(data.terraform_remote_state.data.outputs.db_port) },
      { name = "POSTGRES_DB", value = data.terraform_remote_state.data.outputs.db_name },
      { name = "POSTGRES_USER", value = data.terraform_remote_state.data.outputs.db_username },
    ]

    # ECS fetches this at task start; ":password::" picks the "password" key from the secret's JSON
    secrets = [
      { name = "POSTGRES_PASSWORD", valueFrom = "${local.db_secret_arn}:password::" },
    ]

    # The backend has no ALB, so without this ECS only knows "the process didn't crash".
    # Failing it marks the task UNHEALTHY -> replaced -> circuit breaker rolls back a bad deploy.
    # Liveness (/api/health), not readiness: an RDS blip must not make ECS kill healthy tasks.
    # python:3.12-slim has no curl, so use Python itself.
    healthCheck = {
      command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health', timeout=3)\" || exit 1"]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.backend.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.name}-backend"
  cluster         = data.terraform_remote_state.ecs.outputs.cluster_id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.terraform_remote_state.networking.outputs.private_app_subnet_ids
    security_groups  = [data.terraform_remote_state.networking.outputs.backend_sg_id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.main.arn

    service {
      port_name      = "backend"
      discovery_name = "backend"
      client_alias {
        dns_name = "backend"
        port     = 8000
      }
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # CI owns deployments (new task definition revisions); Terraform only creates the service
  lifecycle {
    ignore_changes = [task_definition]
  }

  # The task can't start until it is allowed to read the secret
  depends_on = [aws_iam_role_policy.execution_read_db_secret]
}
