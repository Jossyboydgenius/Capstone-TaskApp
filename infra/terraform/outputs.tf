output "control_plane_public_ip" {
  description = "Public IP of the control plane server"
  value       = module.compute.server_public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane server"
  value       = module.compute.server_private_ip
}

output "agent_public_ips" {
  description = "Public IPs of the worker agents"
  value       = module.compute.agent_public_ips
}

output "agent_private_ips" {
  description = "Private IPs of the worker agents"
  value       = module.compute.agent_private_ips
}
