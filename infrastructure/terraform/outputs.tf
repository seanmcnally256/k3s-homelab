output "control_public_ip" {
  description = "Public IP — SSH and kubectl from your host"
  value       = aws_instance.control.public_ip
}

output "control_private_ip" {
  description = "Private IP — used internally for worker → control plane communication"
  value       = aws_instance.control.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.workers[*].private_ip
}
