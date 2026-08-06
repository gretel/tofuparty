variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "copyparty-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "container_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "ECS task memory (MiB)"
  type        = number
  default     = 1024
}

variable "container_image" {
  description = "Container image for copyparty"
  type        = string
  default     = "copyparty/ac:latest"
}

variable "container_port" {
  description = "Container port for copyparty HTTP"
  type        = number
  default     = 3923
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "password_length" {
  description = "Length of auto-generated passwords"
  type        = number
  default     = 24
}

variable "health_check_grace_period" {
  description = "ECS service health check grace period (seconds)"
  type        = number
  default     = 60
}
