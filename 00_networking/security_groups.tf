# Egress is limited to what each tier actually talks to. Destinations are subnet CIDRs rather than
# security group IDs: SG references in both directions (ALB -> frontend egress, frontend <- ALB
# ingress) would make a dependency cycle. The ingress side still uses SG references, and traffic
# needs both sides to allow it.
#
# 443 to the internet (via the NAT) stays open for ECR image pulls, CloudWatch Logs and the ECS
# agent. Closing it needs VPC interface endpoints (~$7-8/month each per AZ, ~$40+/month here).

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
    description = "To frontend tasks (requests and health checks)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.private_app_subnets
  }

  tags = {
    Name = "${var.vpc_name}-alb-sg"
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
    description = "To backend tasks (nginx proxies /api via Service Connect)"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.private_app_subnets
  }

  #trivy:ignore:AWS-0104 Accepted: HTTPS to AWS APIs via the NAT; VPC endpoints would cost ~$40+/month
  egress {
    description = "HTTPS to AWS APIs (ECR pulls, CloudWatch Logs, ECS agent)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
    description = "To RDS PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.private_data_subnets
  }

  #trivy:ignore:AWS-0104 Accepted: HTTPS to AWS APIs via the NAT; VPC endpoints would cost ~$40+/month
  egress {
    description = "HTTPS to AWS APIs (ECR pulls, CloudWatch Logs, ECS agent)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
