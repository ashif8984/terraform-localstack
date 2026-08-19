# S3 Bucket Terraform Module

A reusable Terraform module to provision an AWS S3 bucket configured with default server-side encryption, public access blocking, versioning, and optional server access logging.

---

## Usage Instructions

### Step 1: Reference the Module in Your Configuration

Add the module block to your environment's `main.tf` (e.g., `environments/dev/main.tf`):

```hcl
module "s3_bucket" {
  source = "../../modules/s3"

  bucket_name           = var.bucket_name
  environment           = var.environment
  project_name          = var.project_name
  enable_versioning     = true
  enable_logging        = var.enable_logging
  logging_target_bucket = null # provide target bucket name if enable_logging is true
}