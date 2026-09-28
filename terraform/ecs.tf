resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "microservices" {
  for_each = { for srv in local.services : srv.name => srv }
  name     = "/ecs/${var.project_name}-${each.value.name}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "microservices" {
  for_each                 = { for srv in local.services : srv.name => srv }
  family                   = "${var.project_name}-${each.value.name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = "${aws_ecr_repository.services[each.key].repository_url}:latest"
      essential = true
      environment = [
        { name = "DB_HOST", value = aws_db_instance.postgres.address },
        { name = "DB_PORT", value = tostring(aws_db_instance.postgres.port) },
        # Inject the EC2 instance's private IP directly instead of using Route 53 DNS
        { name = "MQ_HOST", value = aws_instance.ibm_mq.private_ip }
      ]
      secrets = [
        {
          name      = "MQ_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.mq_credentials.arn}:mq_app_password::"
        }
      ]
      portMappings = [
        { containerPort = each.value.port, protocol = "tcp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.project_name}-${each.value.name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "microservices" {
  for_each        = { for srv in local.services : srv.name => srv }
  name            = "${var.project_name}-${each.value.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.microservices[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  # If it's the producer service, we attach it to the ALB
  dynamic "load_balancer" {
    for_each = each.value.name == "order-producer-service" ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.producer.arn
      container_name   = each.value.name
      container_port   = each.value.port
    }
  }
}
