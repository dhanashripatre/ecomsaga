variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ecom-saga"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ==============================================================================
# SECRETS (Do not provide defaults, should be injected via CI/CD or separate .tfvars)
# ==============================================================================

variable "db_username" {
  type        = string
  description = "The master username for the PostgreSQL database"
}

variable "db_password" {
  type        = string
  description = "The master password for the PostgreSQL database"
  sensitive   = true
}

variable "mq_app_password" {
  type        = string
  description = "The password for the IBM MQ App user"
  sensitive   = true
}

variable "mq_admin_password" {
  type        = string
  description = "The password for the IBM MQ Admin user"
  sensitive   = true
}
