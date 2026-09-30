resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow ECS Task Execution Role to read secrets from Secrets Manager
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "${var.project_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.db_username.arn,
          aws_ssm_parameter.db_password.arn,
          aws_ssm_parameter.mq_app_password.arn,
          aws_ssm_parameter.mq_admin_password.arn
        ]
      }
    ]
  })
}

# Task Role (for the containers themselves)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# --- EC2 Role for IBM MQ ---
resource "aws_iam_role" "ec2_mq_role" {
  name = "${var.project_name}-ec2-mq-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_mq_profile" {
  name = "${var.project_name}-ec2-mq-profile"
  role = aws_iam_role.ec2_mq_role.name
}

resource "aws_iam_role_policy" "ec2_mq_secrets_policy" {
  name = "${var.project_name}-ec2-mq-secrets-policy"
  role = aws_iam_role.ec2_mq_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.mq_app_password.arn,
          aws_ssm_parameter.mq_admin_password.arn,
          aws_ssm_parameter.db_password.arn
        ]
      }
    ]
  })
}

