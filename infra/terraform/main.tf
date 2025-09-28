resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "Multi-tier-App"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main-IGW"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"       #Larger CIDR block for more IPs
  availability_zone       = "us-east-1a"        #Explicitly specifying an AZ
  map_public_ip_on_launch = true                #Auto-assign public IPs to instances

  tags = {
    Name = "Multi-tier-app-Public-Subnet"
  }
}

#Create the main Route Table for the public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  #Route all IPv4 traffic to the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
    tags = {
        Name = "Public-RT"
    }
}    

#Associate the public subnet with the public route table
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Get current AWS account info
data "aws_caller_identity" "current" {}

# IAM role for Ansible dynamic inventory
resource "aws_iam_role" "ansible_inventory" {
  name = "${var.project_name}-ansible-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ansible-role"
    Project = var.project_name
  }
}

# IAM policy for Ansible inventory
resource "aws_iam_role_policy" "ansible_inventory" {
  name = "${var.project_name}-ansible-policy"
  role = aws_iam_role.ansible_inventory.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeRegions", 
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}