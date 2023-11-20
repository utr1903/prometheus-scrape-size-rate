###########
### VPC ###
###########

# VPC
resource "aws_vpc" "prometheus" {
  cidr_block = "192.168.0.0/16"
}

# Gateway
resource "aws_internet_gateway" "prometheus" {
  vpc_id = aws_vpc.prometheus.id
}

# Subnet
resource "aws_subnet" "prometheus" {
  vpc_id     = aws_vpc.prometheus.id
  cidr_block = "192.168.0.0/24"

  depends_on = [aws_internet_gateway.prometheus]
}

# Route table to internet
resource "aws_route_table" "internet" {
  vpc_id = aws_vpc.prometheus.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prometheus.id
  }
}

# Route table to subnet assosiaction
resource "aws_route_table_association" "prometheus" {
  subnet_id = aws_subnet.prometheus.id
  route_table_id = aws_route_table.internet.id
}
