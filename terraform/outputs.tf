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


output "adminer_url" {
  description = "The URL to access the Adminer database management UI"
  value       = "http://${aws_instance.adminer.public_ip}"
}

output "monitoring_prometheus_url" {
  description = "The URL to access Prometheus"
  value       = "http://${aws_instance.adminer.public_ip}:9090"
}

output "monitoring_grafana_url" {
  description = "The URL to access Grafana"
  value       = "http://${aws_instance.adminer.public_ip}:3000"
}

output "mq_public_ip" {
  description = "The public IP of the IBM MQ EC2 instance"
  value       = aws_instance.ibm_mq.public_ip
}
