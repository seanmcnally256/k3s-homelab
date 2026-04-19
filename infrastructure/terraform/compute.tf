# Latest Ubuntu 22.04 LTS — Canonical's official AWS account
data "aws_ami" "ubuntu_22_04" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH key pair — public key is injected into every instance
resource "aws_key_pair" "k3s" {
  key_name   = "k3s-homelab"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ── Control plane ─────────────────────────────────────────────────────────────

resource "aws_instance" "control" {
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = var.control_instance_type
  key_name               = aws_key_pair.k3s.key_name
  subnet_id              = aws_subnet.k3s.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  user_data = templatefile("${path.module}/../cloud-init.yaml", {
    hostname = "k3s-control"
  })

  tags = { Name = "k3s-control" }
}

# ── Workers ───────────────────────────────────────────────────────────────────

resource "aws_instance" "workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu_22_04.id
  instance_type          = var.worker_instance_type
  key_name               = aws_key_pair.k3s.key_name
  subnet_id              = aws_subnet.k3s.id
  vpc_security_group_ids = [aws_security_group.k3s.id]
  user_data = templatefile("${path.module}/../cloud-init.yaml", {
    hostname = "k3s-worker-${count.index + 1}"
  })

  tags = { Name = "k3s-worker-${count.index + 1}" }
}
