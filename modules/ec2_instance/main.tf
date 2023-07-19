resource "aws_instance" "instance1" {
  ami           = data.aws_ami.amzn_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [
    aws_security_group.ssh_access.id,
    aws_security_group.http_access.id,
  ]

  tags = var.tags

  userData = filebase64("${path.module}/userdata.sh")
}

data "aws_ami" "amzn_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "ssh_access" {
  name = "ssh_access"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}

resource "aws_security_group" "http_access" {
  name = "http_access"

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}