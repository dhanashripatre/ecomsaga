# =============================================================================
#  Makefile — event-driven-microservices-with-ibm-mq
#  Project : ecom-saga
#  Region  : ap-south-1
# =============================================================================
#
#  QUICK REFERENCE
#  ---------------
#  make help            → list every available target
#
#  LOCAL DEV
#  make up              → start full stack (IBM MQ + 4 DBs + 4 services)
#  make down            → tear down all containers
#  make restart         → down then up
#  make logs            → tail logs of all containers
#  make logs-<service>  → tail a single service  (e.g. make logs-producer)
#  make ps              → show container status
#  make clean           → stop containers AND remove volumes (fresh DB state)
#
#  BUILD
#  make build-all       → Maven build all 4 services (skip tests)
#  make test-all        → Maven test all 4 services
#  make build-<svc>     → Maven build one service  (e.g. make build-producer)
#
#  DOCKER
#  make docker-build    → docker-compose build all images
#  make docker-push     → build + push all images to ECR (requires AWS login)
#
#  TERRAFORM
#  make tf-init         → terraform init
#  make tf-plan         → terraform plan
#  make tf-apply        → terraform apply (auto-approve)
#  make tf-destroy      → terraform destroy (prompts for confirmation)
#
#  AWS / ECS
#  make ecr-login       → authenticate Docker with ECR
#  make ecs-deploy      → force a rolling update of all 4 ECS services
#
# =============================================================================

# ── Variables ─────────────────────────────────────────────────────────────────
PROJECT_NAME   := ecom-saga
AWS_REGION     := ap-south-1
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
ECR_REGISTRY   := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

SERVICES := \
  order-producer-service \
  order-inventory-service \
  order-payment-service \
  order-notification-service

# Short aliases used in per-service targets
PRODUCER     := order-producer-service
INVENTORY    := order-inventory-service
PAYMENT      := order-payment-service
NOTIFICATION := order-notification-service

COMPOSE_FILE := docker-compose.yml
TF_DIR       := terraform

# Colour helpers (no-op when stdout is not a terminal)
BOLD  := \033[1m
RESET := \033[0m
GREEN := \033[0;32m
CYAN  := \033[0;36m
RED   := \033[0;31m

.DEFAULT_GOAL := help
.PHONY: help \
        up down restart logs ps clean \
        logs-producer logs-inventory logs-payment logs-notification \
        build-all test-all \
        build-producer build-inventory build-payment build-notification \
        docker-build docker-push \
        ecr-login ecs-deploy \
        tf-init tf-plan tf-apply tf-destroy \
        env-check

# =============================================================================
#  HELP
# =============================================================================
help:
	@echo ""
	@echo "$(BOLD)$(CYAN)ecom-saga — available make targets$(RESET)"
	@echo "──────────────────────────────────────────────────────────────────"
	@echo "$(BOLD)LOCAL DEVELOPMENT$(RESET)"
	@echo "  up                   Start the full stack (IBM MQ, DBs, services)"
	@echo "  down                 Stop and remove containers"
	@echo "  restart              down → up"
	@echo "  logs                 Tail logs of all containers"
	@echo "  logs-producer        Tail order-producer-service logs"
	@echo "  logs-inventory       Tail order-inventory-service logs"
	@echo "  logs-payment         Tail order-payment-service logs"
	@echo "  logs-notification    Tail order-notification-service logs"
	@echo "  ps                   Show running container status"
	@echo "  clean                Stop containers + wipe volumes (fresh DB)"
	@echo ""
	@echo "$(BOLD)BUILD & TEST$(RESET)"
	@echo "  build-all            Maven build all 4 services (skip tests)"
	@echo "  test-all             Maven test all 4 services"
	@echo "  build-producer       Build order-producer-service only"
	@echo "  build-inventory      Build order-inventory-service only"
	@echo "  build-payment        Build order-payment-service only"
	@echo "  build-notification   Build order-notification-service only"
	@echo ""
	@echo "$(BOLD)DOCKER$(RESET)"
	@echo "  docker-build         docker-compose build (all services)"
	@echo "  docker-push          Build images + push to AWS ECR"
	@echo ""
	@echo "$(BOLD)TERRAFORM (AWS IaC)$(RESET)"
	@echo "  tf-init              terraform init"
	@echo "  tf-plan              terraform plan"
	@echo "  tf-apply             terraform apply --auto-approve"
	@echo "  tf-destroy           terraform destroy (confirmation required)"
	@echo ""
	@echo "$(BOLD)AWS / ECS$(RESET)"
	@echo "  ecr-login            Authenticate Docker with Amazon ECR"
	@echo "  ecs-deploy           Force rolling update for all 4 ECS services"
	@echo ""

# =============================================================================
#  LOCAL DEVELOPMENT
# =============================================================================
up:
	@echo "$(GREEN)▶ Starting full stack...$(RESET)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✔ Stack is up. Services:$(RESET)"
	@echo "   Producer    → http://localhost:8080/api/producer"
	@echo "   Inventory   → http://localhost:8081/api/inventory"
	@echo "   Payment     → http://localhost:8082/api/payment"
	@echo "   Notification→ http://localhost:8083/api/notification"
	@echo "   IBM MQ UI   → https://localhost:9443/ibmmq/console"

down:
	@echo "$(RED)▶ Stopping stack...$(RESET)"
	docker-compose -f $(COMPOSE_FILE) down

restart: down up

logs:
	docker-compose -f $(COMPOSE_FILE) logs -f

logs-producer:
	docker-compose -f $(COMPOSE_FILE) logs -f order-producer-service

logs-inventory:
	docker-compose -f $(COMPOSE_FILE) logs -f order-inventory-service

logs-payment:
	docker-compose -f $(COMPOSE_FILE) logs -f order-payment-service

logs-notification:
	docker-compose -f $(COMPOSE_FILE) logs -f order-notification-service

ps:
	docker-compose -f $(COMPOSE_FILE) ps

## Stop containers AND delete all volumes (wipes Postgres data — use with care)
clean:
	@echo "$(RED)▶ Tearing down containers and removing volumes...$(RESET)"
	docker-compose -f $(COMPOSE_FILE) down -v --remove-orphans
	@echo "$(GREEN)✔ Clean complete.$(RESET)"

# =============================================================================
#  BUILD & TEST  (Maven — runs on host, not inside Docker)
# =============================================================================
build-all:
	@echo "$(CYAN)▶ Building all services...$(RESET)"
	@for svc in $(SERVICES); do \
	  echo "$(BOLD)  → $$svc$(RESET)"; \
	  cd $$svc && mvn clean package -DskipTests -q && cd ..; \
	done
	@echo "$(GREEN)✔ All services built.$(RESET)"

test-all:
	@echo "$(CYAN)▶ Running tests for all services...$(RESET)"
	@for svc in $(SERVICES); do \
	  echo "$(BOLD)  → $$svc$(RESET)"; \
	  cd $$svc && mvn test && cd ..; \
	done
	@echo "$(GREEN)✔ Tests complete.$(RESET)"

build-producer:
	@echo "$(CYAN)▶ Building $(PRODUCER)...$(RESET)"
	cd $(PRODUCER) && mvn clean package -DskipTests
	@echo "$(GREEN)✔ Done.$(RESET)"

build-inventory:
	@echo "$(CYAN)▶ Building $(INVENTORY)...$(RESET)"
	cd $(INVENTORY) && mvn clean package -DskipTests
	@echo "$(GREEN)✔ Done.$(RESET)"

build-payment:
	@echo "$(CYAN)▶ Building $(PAYMENT)...$(RESET)"
	cd $(PAYMENT) && mvn clean package -DskipTests
	@echo "$(GREEN)✔ Done.$(RESET)"

build-notification:
	@echo "$(CYAN)▶ Building $(NOTIFICATION)...$(RESET)"
	cd $(NOTIFICATION) && mvn clean package -DskipTests
	@echo "$(GREEN)✔ Done.$(RESET)"

# =============================================================================
#  DOCKER
# =============================================================================
docker-build:
	@echo "$(CYAN)▶ Building Docker images via docker-compose...$(RESET)"
	docker-compose -f $(COMPOSE_FILE) build
	@echo "$(GREEN)✔ Images built.$(RESET)"

## Build each service image locally + tag + push to ECR
docker-push: ecr-login
	@echo "$(CYAN)▶ Building and pushing images to ECR...$(RESET)"
	@for svc in $(SERVICES); do \
	  echo "$(BOLD)  → $$svc$(RESET)"; \
	  docker build -t $(ECR_REGISTRY)/$(PROJECT_NAME)/$$svc:latest $$svc; \
	  docker push $(ECR_REGISTRY)/$(PROJECT_NAME)/$$svc:latest; \
	done
	@echo "$(GREEN)✔ All images pushed to ECR.$(RESET)"

# =============================================================================
#  AWS AUTHENTICATION
# =============================================================================
ecr-login:
	@echo "$(CYAN)▶ Logging in to Amazon ECR ($(AWS_REGION))...$(RESET)"
	aws ecr get-login-password --region $(AWS_REGION) | \
	  docker login --username AWS --password-stdin $(ECR_REGISTRY)
	@echo "$(GREEN)✔ ECR login successful.$(RESET)"

# =============================================================================
#  ECS DEPLOYMENT  (mirrors what deploy.yml does)
# =============================================================================
ecs-deploy:
	@echo "$(CYAN)▶ Triggering rolling ECS update for all services...$(RESET)"
	@for svc in $(SERVICES); do \
	  echo "  → $(PROJECT_NAME)-$$svc-service"; \
	  aws ecs update-service \
	    --region $(AWS_REGION) \
	    --cluster $(PROJECT_NAME)-cluster \
	    --service $(PROJECT_NAME)-$$svc-service \
	    --force-new-deployment \
	    --output text --query 'service.serviceName'; \
	done
	@echo "$(GREEN)✔ ECS deployments triggered.$(RESET)"

# =============================================================================
#  TERRAFORM
# =============================================================================
tf-init:
	@echo "$(CYAN)▶ Initialising Terraform...$(RESET)"
	cd $(TF_DIR) && terraform init

tf-plan:
	@echo "$(CYAN)▶ Terraform plan...$(RESET)"
	cd $(TF_DIR) && terraform plan

tf-apply:
	@echo "$(CYAN)▶ Terraform apply (auto-approve)...$(RESET)"
	cd $(TF_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)✔ Infrastructure applied.$(RESET)"

tf-destroy:
	@echo "$(RED)▶ Terraform destroy — this will DELETE all AWS resources!$(RESET)"
	@read -p "  Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(TF_DIR) && terraform destroy
