#!/bin/bash
# get-urls.sh
# Run from the project root: bash get-urls.sh

cd "$(dirname "$0")/terraform" || exit 1

# Fetch dynamic values from Terraform outputs
ALB_DNS=$(terraform output -raw alb_dns_name)
ALB_URL="http://$ALB_DNS"
MQ_IP=$(terraform output -raw mq_public_ip)
ADMINER_URL=$(terraform output -raw adminer_url)
PROMETHEUS_URL=$(terraform output -raw monitoring_prometheus_url)
GRAFANA_URL=$(terraform output -raw monitoring_grafana_url)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_HOST="${RDS_ENDPOINT%:*}"

echo ""
echo "==========================================="
echo "   ECOM-SAGA - LIVE URLS & ENDPOINTS"
echo "==========================================="

echo ""
echo "1. PRODUCER SERVICE (only one accessible via ALB)"
echo "-------------------------------------------"
echo "  Create Order  : POST $ALB_URL/api/producer/send?product=Laptop&quantity=2"
echo "  Health Check  : GET  $ALB_URL/api/producer/actuator/health"
echo "  Swagger UI    : $ALB_URL/api/producer/swagger-ui/index.html"

echo ""
echo "2. INVENTORY SERVICE (internal only)"
echo "-------------------------------------------"
echo "  Health Check  : GET  $ALB_URL/api/inventory/actuator/health"
echo "  Swagger UI    : $ALB_URL/api/inventory/swagger-ui/index.html"

echo ""
echo "3. PAYMENT SERVICE (internal only)"
echo "-------------------------------------------"
echo "  Health Check  : GET  $ALB_URL/api/payment/actuator/health"
echo "  Swagger UI    : $ALB_URL/api/payment/swagger-ui/index.html"

echo ""
echo "4. NOTIFICATION SERVICE (internal only)"
echo "-------------------------------------------"
echo "  Health Check  : GET  $ALB_URL/api/notification/actuator/health"
echo "  Swagger UI    : $ALB_URL/api/notification/swagger-ui/index.html"

echo ""
echo "==========================================="
echo "   MESSAGING"
echo "==========================================="
echo "  IBM MQ Console : https://$MQ_IP:9443/ibmmq/console/"
echo "  Login          : admin / (mq_admin_password from SSM)"

echo ""
echo "==========================================="
echo "   DATABASE"
echo "==========================================="
echo "  Adminer UI  : $ADMINER_URL"
echo "  Login       : postgres / (db_password from SSM)"
echo ""
echo "  RDS Host    : $RDS_HOST"
echo "  Port        : 5432"
echo "  Username    : postgres"
echo ""
echo "  Databases inside this RDS instance:"
echo "    • producer_db      (Producer Service)"
echo "    • inventory_db     (Inventory Service)"
echo "    • payment_db       (Payment Service)"
echo "    • notification_db  (Notification Service)"

echo ""
echo "==========================================="
echo "   MONITORING"
echo "==========================================="
echo "  Prometheus : $PROMETHEUS_URL"
echo "  Grafana    : $GRAFANA_URL"
echo "  Grafana Login : admin / admin (change on first login)"
echo "  Recommended Dashboard IDs: 19004 (Spring Boot), 4701 (JVM)"

echo ""
echo "==========================================="
echo "   QUICK TEST COMMANDS"
echo "==========================================="
echo "  # Create an order:"
echo "  curl -X POST \"$ALB_URL/api/producer/send?product=Laptop&quantity=2\""
echo ""
echo "  # Check producer health:"
echo "  curl \"$ALB_URL/api/producer/actuator/health\""
echo ""
echo "==========================================="
