resource "aws_instance" "adminer" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.adminer.id]
  iam_instance_profile        = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker

# Run Adminer
docker run -d \
  --name adminer \
  --restart always \
  -p 80:8080 \
  -e ADMINER_DEFAULT_SERVER="${aws_db_instance.postgres.address}" \
  -e ADMINER_DESIGN="pepa-linha" \
  adminer:latest

# Create prometheus config
mkdir -p /opt/prometheus
cat << 'PROMETHEUS' > /opt/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ecs-microservices'
    ecs_sd_configs:
      - region: ${var.aws_region}
        cluster: ${aws_ecs_cluster.main.name}
        port: 8080
    relabel_configs:
      - source_labels: [__meta_ecs_container_name]
        regex: 'order-(.*)-service'
        target_label: __metrics_path__
        replacement: '/api/$${1}/actuator/prometheus'
      - source_labels: [__meta_ecs_container_name]
        target_label: service
PROMETHEUS

chmod 777 /opt/prometheus/prometheus.yml

# Run Prometheus
docker run -d --name prometheus \
  --restart always \
  -p 9090:9090 \
  -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest

# Run Grafana
docker run -d --name grafana \
  --restart always \
  -p 3000:3000 \
  grafana/grafana:latest
  EOF

  tags = {
    Name = "${var.project_name}-adminer-ec2"
  }
}
