resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/db-credentials"
  description             = "PostgreSQL credentials"
  recovery_window_in_days = 0 # Force delete for dev environments
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

resource "aws_secretsmanager_secret" "mq_credentials" {
  name                    = "${var.project_name}/${var.environment}/mq-credentials"
  description             = "IBM MQ App and Admin passwords"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mq_credentials" {
  secret_id = aws_secretsmanager_secret.mq_credentials.id
  secret_string = jsonencode({
    mq_app_password   = var.mq_app_password
    mq_admin_password = var.mq_admin_password
  })
}
