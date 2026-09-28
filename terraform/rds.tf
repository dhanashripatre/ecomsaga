resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "${var.project_name}-postgres"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = "producer_db" # Master DB, others to be created logically
  username             = "postgres"
  # Pulling password directly from Secrets Manager data source might cause circular issues in some setups,
  # but assuming the secret exists or is updated externally. For best practices, pass via variable or SSM.
  password             = jsondecode(aws_secretsmanager_secret_version.db_credentials.secret_string)["password"]
  
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.db.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
