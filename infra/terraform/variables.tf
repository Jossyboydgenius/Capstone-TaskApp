variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "The availability zone to deploy the subnet in"
  type        = string
  default     = "us-east-1a"
}

variable "instance_type" {
  description = "The instance type to use for instances"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "SSH key pair name to associate with VMs"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID to use for the VMs (Ubuntu 22.04 LTS recommended)"
  type        = string
  # Default Ubuntu 22.04 LTS AMI in us-east-1 (as of mid-2023/2024, subject to change)
  default     = "ami-0c7217cdde317cfec" 
}

variable "env" {
  description = "Environment name for tagging"
  type        = string
  default     = "phoenix-capstone"
}

variable "agent_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 2
}

variable "admin_ip" {
  description = "The administrator's local machine IP in CIDR notation (e.g. X.X.X.X/32) to isolate SSH and Kubernetes API"
  type        = string
}
