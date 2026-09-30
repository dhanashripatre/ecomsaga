resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow inbound HTTP access to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound access for ECS tasks from ALB and within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8083
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8083
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow inbound access to RDS from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [aws_security_group.ecs_tasks.id, aws_security_group.mq.id, aws_security_group.adminer.id]
  }
}

resource "aws_security_group" "adminer" {
  name        = "${var.project_name}-adminer-sg"
  description = "Allow inbound HTTP access to Adminer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mq" {
  name        = "${var.project_name}-mq-sg"
  description = "Allow inbound access to MQ from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 1414
    to_port         = 1414
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9443
    to_port     = 9443
    cidr_blocks = ["0.0.0.0/0"] # Admin console (ideally restrict to VPN/bastion in prod)
  }


  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
