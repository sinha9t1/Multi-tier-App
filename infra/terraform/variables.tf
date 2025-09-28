variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project for tagging resources"
  type        = string
  default     = "Multi-Tier-App"
}

variable Environment {
  description = "The environment for the deployment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable Role {
  description = "The role of the instance (e.g., Master, Web, App, DB)"
  type        = string
  default     = "Master"
}

