resource "aws_security_group" "alb" {
  name        = "${var.vpc_name}-alb-sg"
  description = "Allow HTTP and HTTPS from internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-alb-sg"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.vpc_name}-ecs-tasks-sg"
  description = "Allow traffic from ALB to ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-ecs-tasks-sg"
  }
}

resource "aws_security_group" "frontend" {
  name        = "${var.vpc_name}-frontend-sg"
  description = "Allow traffic from ALB to frontend ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-frontend-sg"
  }
}

resource "aws_security_group" "backend" {
  name        = "${var.vpc_name}-backend-sg"
  description = "Allow traffic from frontend ECS tasks to backend ECS tasks only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow from frontend ECS tasks"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-backend-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.vpc_name}-rds-sg"
  description = "Allow traffic from backend ECS tasks to RDS only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow from backend ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }


  tags = {
    Name = "${var.vpc_name}-rds-sg"
  }
} 