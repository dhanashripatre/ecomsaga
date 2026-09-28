provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

locals {
  services = [
    { name = "order-producer-service", port = 8080 },
    { name = "order-inventory-service", port = 8081 },
    { name = "order-payment-service", port = 8082 },
    { name = "order-notification-service", port = 8083 }
  ]
}
