output "server_public_ip" {
  description = "Public IP of the control plane"
  value       = aws_instance.server.public_ip
}

output "server_private_ip" {
  description = "Private IP of the control plane"
  value       = aws_instance.server.private_ip
}

output "agent_public_ips" {
  description = "Public IPs of the worker agents"
  value       = aws_instance.agent[*].public_ip
}

output "agent_private_ips" {
  description = "Private IPs of the worker agents"
  value       = aws_instance.agent[*].private_ip
}
