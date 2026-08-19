terraform {
  backend "s3" {
    bucket         = "s3-state-bucket"
    key            = "environments/dev/terraform.tfstate" # Different key per environment
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    # use_lockfile   = true
    encrypt        = true
  }
}