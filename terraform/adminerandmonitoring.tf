resource "aws_instance" "adminer" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.adminer.id]
  iam_instance_profile        = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
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
  # --- Producer service (port 8080) ---
  - job_name: 'order-producer-service'
    ecs_sd_configs:
      - region: ${var.aws_region}
        port: 8080
    relabel_configs:
      - source_labels: [__meta_ecs_cluster]
        regex: '${aws_ecs_cluster.main.name}'
        action: keep
      - source_labels: [__meta_ecs_service]
        regex: '.*order-producer-service.*'
        action: keep
      - target_label: __metrics_path__
        replacement: '/api/producer/actuator/prometheus'
      - target_label: service
        replacement: 'order-producer-service'

  # --- Inventory service (port 8081) ---
  - job_name: 'order-inventory-service'
    ecs_sd_configs:
      - region: ${var.aws_region}
        port: 8081
    relabel_configs:
      - source_labels: [__meta_ecs_cluster]
        regex: '${aws_ecs_cluster.main.name}'
        action: keep
      - source_labels: [__meta_ecs_service]
        regex: '.*order-inventory-service.*'
        action: keep
      - target_label: __metrics_path__
        replacement: '/api/inventory/actuator/prometheus'
      - target_label: service
        replacement: 'order-inventory-service'

  # --- Payment service (port 8082) ---
  - job_name: 'order-payment-service'
    ecs_sd_configs:
      - region: ${var.aws_region}
        port: 8082
    relabel_configs:
      - source_labels: [__meta_ecs_cluster]
        regex: '${aws_ecs_cluster.main.name}'
        action: keep
      - source_labels: [__meta_ecs_service]
        regex: '.*order-payment-service.*'
        action: keep
      - target_label: __metrics_path__
        replacement: '/api/payment/actuator/prometheus'
      - target_label: service
        replacement: 'order-payment-service'

  # --- Notification service (port 8083) ---
  - job_name: 'order-notification-service'
    ecs_sd_configs:
      - region: ${var.aws_region}
        port: 8083
    relabel_configs:
      - source_labels: [__meta_ecs_cluster]
        regex: '${aws_ecs_cluster.main.name}'
        action: keep
      - source_labels: [__meta_ecs_service]
        regex: '.*order-notification-service.*'
        action: keep
      - target_label: __metrics_path__
        replacement: '/api/notification/actuator/prometheus'
      - target_label: service
        replacement: 'order-notification-service'
PROMETHEUS

chmod 644 /opt/prometheus/prometheus.yml

# Run Prometheus
docker run -d --name prometheus \
  --restart always \
  -p 9090:9090 \
  -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest

# Auto-provision Grafana datasources: Prometheus + Loki
mkdir -p /opt/grafana/provisioning/datasources
cat << 'DATASOURCE' > /opt/grafana/provisioning/datasources/datasources.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    isDefault: false
    editable: true
DATASOURCE

# Run Grafana with auto-provisioned datasources
docker run -d --name grafana \
  --restart always \
  --network host \
  -v /opt/grafana/provisioning:/etc/grafana/provisioning \
  -e GF_SECURITY_ADMIN_PASSWORD=admin \
  grafana/grafana:latest

# ── LOKI (log storage) ──────────────────────────────────────────────────────
mkdir -p /opt/loki
cat << 'LOKI_CONFIG' > /opt/loki/loki-config.yml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  allow_structured_metadata: false
LOKI_CONFIG

chmod 644 /opt/loki/loki-config.yml

docker run -d --name loki \
  --restart always \
  --network host \
  -v /opt/loki/loki-config.yml:/etc/loki/local-config.yaml \
  -v /opt/loki/data:/loki \
  grafana/loki:latest

# ── PROMTAIL (ships CloudWatch logs → Loki) ──────────────────────────────────
mkdir -p /opt/promtail
cat << 'PROMTAIL_CONFIG' > /opt/promtail/promtail-config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

scrape_configs:
  - job_name: cloudwatch-ecs-logs
    cloudwatch_config:
      region: ${var.aws_region}
      log_groups:
        - names:
            - /ecs/${var.project_name}-order-producer-service
            - /ecs/${var.project_name}-order-inventory-service
            - /ecs/${var.project_name}-order-payment-service
            - /ecs/${var.project_name}-order-notification-service
          log_stream_prefix: ecs
          labels:
            project: ${var.project_name}
            platform: ecs-fargate
    relabel_configs:
      - source_labels: [__aws_cloudwatch_log_group]
        target_label: log_group
      - source_labels: [__aws_cloudwatch_log_stream]
        target_label: log_stream
      - source_labels: [__aws_cloudwatch_log_group]
        regex: '.*/ecs/${var.project_name}-(.*)-service'
        target_label: service
        replacement: '$${1}-service'
PROMTAIL_CONFIG

chmod 644 /opt/promtail/promtail-config.yml

docker run -d --name promtail \
  --restart always \
  --network host \
  -v /opt/promtail/promtail-config.yml:/etc/promtail/config.yml \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml
  EOF

  tags = {
    Name = "${var.project_name}-adminer-ec2"
  }
}
