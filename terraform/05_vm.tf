##########
### VM ###
##########

# Security group
resource "aws_security_group" "prometheus" {
  name        = "Prometheus"
  description = "Allow inbound and outbound traffic"
  vpc_id      = aws_vpc.prometheus.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  ingress {
    description      = "Prometheus"
    from_port        = 9090
    to_port          = 9090
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
  }

  egress {
    description      = ""
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []

    prefix_list_ids = []
    security_groups = []
    self            = false
  }
}

# TLS private key
resource "tls_private_key" "prometheus" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key pair for SSH
resource "aws_key_pair" "prometheus" {
  key_name   = "prometheus"
  public_key = tls_private_key.prometheus.public_key_openssh
}

# VM
resource "aws_instance" "prometheus" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  subnet_id              = aws_subnet.prometheus.id
  vpc_security_group_ids = [aws_security_group.prometheus.id]

  key_name = aws_key_pair.prometheus.key_name

  user_data = "${file("../scripts/01_run_setup.sh")}"
}

# Public IP
resource "aws_eip" "prometheus" {
  instance = aws_instance.prometheus.id
  domain   = "vpc"

  depends_on = [aws_internet_gateway.prometheus]
}
