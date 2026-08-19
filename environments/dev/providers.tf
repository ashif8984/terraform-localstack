provider "aws" {

  access_key = var.use_localstack ? "mock_access_key" : null
  secret_key = var.use_localstack ? "mock_secret_key" : null
  region     = var.aws_region

  s3_use_path_style           = var.use_localstack
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack

  dynamic "endpoints" {
    for_each = var.use_localstack ? [1] : []

    content {
      s3 = "http://s3.localhost.localstack.cloud:4566"
    }
  }
}