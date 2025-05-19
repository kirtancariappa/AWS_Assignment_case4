provider "aws" {
  region = var.region
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_subnet" "az_subnets" {
  count                   = 3
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-${count.index + 1}"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  count          = 3
  subnet_id      = aws_subnet.az_subnets[count.index].id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "shared_bucket" {
  bucket = var.s3_bucket_name
  force_destroy = true

}

resource "aws_instance" "ec2_instances" {
  count         = 3
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.az_subnets[count.index].id
  key_name      = var.key_name
  security_groups = [aws_security_group.instance_sg.id]
  user_data     = file("user_data.sh")

  tags = {
    Name = "ec2-${count.index + 1}"
  }
}
