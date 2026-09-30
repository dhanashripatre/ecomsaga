resource "aws_instance" "adminer" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.adminer.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker

docker run -d \
  --name adminer \
  --restart always \
  -p 80:8080 \
  -e ADMINER_DEFAULT_SERVER="${aws_db_instance.postgres.address}" \
  -e ADMINER_DESIGN="pepa-linha" \
  adminer:latest
  EOF

  tags = {
    Name = "${var.project_name}-adminer-ec2"
  }
}
