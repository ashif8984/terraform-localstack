variable "environment" {
  type        = string
  description = "The deployment environment (e.g., dev, stage, prod)."
}

variable "project_name" {
  type        = string
  description = "The name of the project."
}

variable "enable_logging" {
  type        = bool
  description = "Flag to enable or disable access/resource logging."
  default     = false
}

variable "aws_region" {
  type        = string
  description = "AWS region for the deployment."
  default     = "us-east-1"
}

variable "use_localstack" {
  type        = bool
  description = "Use LocalStack endpoints and mock credentials for local development."
  default     = true
}