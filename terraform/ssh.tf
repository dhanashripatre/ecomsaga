resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_key_pair" {
  key_name   = "${var.project_name}-bastion-key"
  public_key = tls_private_key.bastion_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = "${path.module}/${var.project_name}-bastion.pem"
}
