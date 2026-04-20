terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Credentials come from ~/.aws/credentials (aws configure) or environment variables
provider "aws" {
  region = var.region
}

# ── Networking ────────────────────────────────────────────────────────────────

resource "aws_vpc" "k3s" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "k3s-homelab" }
}

resource "aws_internet_gateway" "k3s" {
  vpc_id = aws_vpc.k3s.id

  tags = { Name = "k3s-igw" }
}

resource "aws_subnet" "k3s" {
  vpc_id                  = aws_vpc.k3s.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = { Name = "k3s-subnet" }
}

resource "aws_route_table" "k3s" {
  vpc_id = aws_vpc.k3s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k3s.id
  }

  tags = { Name = "k3s-routes" }
}

resource "aws_route_table_association" "k3s" {
  subnet_id      = aws_subnet.k3s.id
  route_table_id = aws_route_table.k3s.id
}

resource "aws_security_group" "k3s" {
  name   = "k3s-sg"
  vpc_id = aws_vpc.k3s.id

  # SSH from anywhere — protected by key-only auth + fail2ban
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # k3s API server — kubectl from your laptop
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP — Nginx ingress
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — Nginx ingress
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All internal cluster traffic (node-to-node, pod-to-pod)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # All outbound allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "k3s-sg" }
}
