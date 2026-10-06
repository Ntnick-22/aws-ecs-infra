# RDS requires subnets in at least 2 AZs, even for a single-AZ instance
resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db-subnets"
  subnet_ids = data.terraform_remote_state.networking.outputs.private_data_subnet_ids

  tags = {
    Name = "${var.name}-db-subnets"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  # RDS generates the password and stores it in Secrets Manager; it never enters Terraform state
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [data.terraform_remote_state.networking.outputs.rds_sg_id]
  publicly_accessible    = false
  multi_az               = false

  # Learning stack, destroyed nightly: no backups, no final snapshot, no protection.
  # In production all three are the opposite.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  # The class is chosen at creation (possibly a fallback). Later applies must not try to
  # resize it back to the preferred class: that would hit the same capacity shortage.
  lifecycle {
    ignore_changes = [instance_class]
  }

  tags = {
    Name = "${var.name}-db"
  }
}
