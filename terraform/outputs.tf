output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.postgres.endpoint
}

output "ecr_repository_urls" {
  description = "URLs for the created ECR repositories"
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}

output "bastion_public_ip" {
  description = "The public IP of the IBM MQ EC2 instance (used as Bastion Host for SSH tunneling)"
  value       = aws_instance.ibm_mq.public_ip
}
