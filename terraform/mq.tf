data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "ibm_mq" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro" # Changed to micro for Free Tier limits

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mq.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_mq_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
# Force recreation to apply correct IAM permissions
dnf update -y
dnf install -y docker jq postgresql15
systemctl start docker
systemctl enable docker

# Fetch credentials from SSM Parameter Store securely
APP_PASS=$(aws ssm get-parameter --name "${aws_ssm_parameter.mq_app_password.name}" --with-decryption --region ${var.aws_region} --query Parameter.Value --output text)
ADMIN_PASS=$(aws ssm get-parameter --name "${aws_ssm_parameter.mq_admin_password.name}" --with-decryption --region ${var.aws_region} --query Parameter.Value --output text)
DB_PASS=$(aws ssm get-parameter --name "${aws_ssm_parameter.db_password.name}" --with-decryption --region ${var.aws_region} --query Parameter.Value --output text)

# Create logically required databases in RDS
export PGPASSWORD=$DB_PASS
for db in inventory_db payment_db notification_db; do
  psql -h ${aws_db_instance.postgres.address} -U postgres -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1 || psql -h ${aws_db_instance.postgres.address} -U postgres -d postgres -c "CREATE DATABASE $db;"
done
# Create MQSC configuration file to auto-create queues
cat << 'MQSC' > /home/ec2-user/20-queues.mqsc
${file("../mq-config/20-queues.mqsc")}
MQSC

docker run -d \
  --name ibm-mq \
  --restart always \
  -e LICENSE=accept \
  -e MQ_QMGR_NAME=QM1 \
  -e MQ_APP_PASSWORD="$APP_PASS" \
  -e MQ_ADMIN_PASSWORD="$ADMIN_PASS" \
  -v /home/ec2-user/20-queues.mqsc:/etc/mqm/20-queues.mqsc \
  -p 1414:1414 -p 9443:9443 \
  icr.io/ibm-messaging/mq:latest
  EOF

  tags = {
    Name = "${var.project_name}-ibm-mq-ec2"
  }
}

