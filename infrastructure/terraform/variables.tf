variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

# t3.micro = free tier eligible (1 vCPU, 1 GB) — tight but functional for k3s
# t3.small = 1 vCPU, 2 GB — recommended for comfort
variable "control_instance_type" { default = "t3.small" }
variable "worker_instance_type"  { default = "t3.small" }
variable "worker_count"          { default = 2 }
