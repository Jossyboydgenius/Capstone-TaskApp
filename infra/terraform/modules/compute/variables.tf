variable "public_subnet_id" {
  description = "The subnet ID to launch instances in"
  type        = string
}

variable "security_group_id" {
  description = "The security group ID to assign to instances"
  type        = string
}

variable "instance_type" {
  description = "The instance type to use for instances"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the VMs (Ubuntu 22.04 LTS recommended)"
  type        = string
}

variable "env" {
  description = "Environment name for tagging"
  type        = string
}

variable "agent_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}
