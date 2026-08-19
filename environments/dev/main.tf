# s3 bucket for application
module "application_bucket" {
  source         = "../../modules/s3"
  bucket_name    = "${var.project_name}-${var.environment}"
  environment    = var.environment
  enable_logging = var.enable_logging
  project_name   = var.project_name
}


module "networking_bucket" {
  source         = "../../modules/s3"
  bucket_name    = "${var.project_name}-${var.environment}-network"
  environment    = var.environment
  enable_logging = var.enable_logging
  project_name   = var.project_name
}