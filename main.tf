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

# Create S3 Bucket

resource "aws_s3_bucket" "shared_bucket" {
  bucket = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name = "SharedEC2S3Bucket"
  }
}

# IAM Role for EC2 to Access S3

resource "aws_iam_role" "ec2_s3_access" {
  name = "EC2S3AccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach S3 policy
resource "aws_iam_role_policy_attachment" "s3_access_attach" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2S3InstanceProfile"
  role = aws_iam_role.ec2_s3_access.name
}


# Launch 3 EC2 instances

resource "aws_instance" "ec2" {
  count         = 3
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.az_subnets[count.index].id
  key_name      = var.key_name
  security_groups = [aws_security_group.instance_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  

  tags = {
    Name = "ec2-instance-${count.index + 1}"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y software-properties-common
              sudo add-apt-repository -y ppa:sebastian-stenzel/cryptomator
              sudo apt update -y
              sudo apt install -y s3fs
              mkdir -p /mnt/s3bucket
              s3fs ${aws_s3_bucket.shared_bucket.bucket} /mnt/s3bucket -o iam_role=auto -o allow_other
              sudo yum update -y
              sudo yum install -y docker.io git unzip

              # Start Docker
              sudo systemctl start docker
              sudo systemctl enable docker

              EOF
}
