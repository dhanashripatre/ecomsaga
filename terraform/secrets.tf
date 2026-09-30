resource "aws_ssm_parameter" "db_username" {
  name        = "/${var.project_name}/${var.environment}/db-username"
  description = "PostgreSQL username"
  type        = "String"
  value       = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/${var.environment}/db-password"
  description = "PostgreSQL password"
  type        = "SecureString"
  value       = var.db_password
}

resource "aws_ssm_parameter" "mq_app_password" {
  name        = "/${var.project_name}/${var.environment}/mq-app-password"
  description = "IBM MQ App password"
  type        = "SecureString"
  value       = var.mq_app_password
}

resource "aws_ssm_parameter" "mq_admin_password" {
  name        = "/${var.project_name}/${var.environment}/mq-admin-password"
  description = "IBM MQ Admin password"
  type        = "SecureString"
  value       = var.mq_admin_password
}
