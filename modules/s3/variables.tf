variable "bucket_name" {
  type        = string
  description = "Globally unique name for the S3 bucket."
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
}

variable "project_name" {
  type        = string
  description = "Project name."
}

variable "enable_versioning" {
  type        = bool
  description = "Enable object versioning on the bucket."
  default     = true
}

variable "enable_logging" {
  type        = bool
  description = "Enable server access logging."
  default     = false
}

variable "logging_target_bucket" {
  type        = string
  description = "Target bucket name for server access logs (required if enable_logging is true)."
  default     = null
}