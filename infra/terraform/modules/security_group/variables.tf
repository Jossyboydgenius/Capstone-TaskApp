variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "env" {
  description = "Environment name for tagging"
  type        = string
}

variable "admin_ip" {
  description = "The administrator's local machine IP in CIDR notation (e.g. X.X.X.X/32) to isolate SSH and Kubernetes API"
  type        = string
}
