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
  key_name      = aws_key_pair.bastion_key_pair.key_name

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.mq.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_mq_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y docker jq
systemctl start docker
systemctl enable docker

# Fetch credentials from Secrets Manager securely
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mq_credentials.name} --region ${var.aws_region} --query SecretString --output text)
APP_PASS=$(echo $SECRET_JSON | jq -r .mq_app_password)
ADMIN_PASS=$(echo $SECRET_JSON | jq -r .mq_admin_password)

docker run -d \
  --name ibm-mq \
  --restart always \
  -e LICENSE=accept \
  -e MQ_QMGR_NAME=QM1 \
  -e MQ_APP_PASSWORD=$APP_PASS \
  -e MQ_ADMIN_PASSWORD=$ADMIN_PASS \
  -p 1414:1414 -p 9443:9443 \
  icr.io/ibm-messaging/mq:latest
  EOF

  tags = {
    Name = "${var.project_name}-ibm-mq-ec2"
  }
}

