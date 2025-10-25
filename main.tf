# 1. CONFIGURE THE AWS PROVIDER
provider "aws" {
  region = "us-east-1" # Region where most resources will be deployed
}

# 2. CREATE THE S3 BUCKET FOR REMOTE STATE
# NOTE: This is done locally first, then uncomment the "terraform" backend block below and run init again.
resource "aws_s3_bucket" "terraform_backend" {
  bucket = "my-cool-bucket-lukeresume-terraform" # <-- REPLACE with a globally unique name!

  force_destroy = true

  # Enforce public access block for security
  acl = "private" 

  tags = {
    Name = "CloudResumeTFState"
  }
}

# 3. CONFIGURE REMOTE BACKEND (UNCOMMENT AFTER FIRST 'terraform apply' to create the S3 bucket)
terraform {
  backend "s3" {
    bucket         = "my-cool-bucket-lukeresume-terraform" # <-- MATCH the bucket name above
    key            = "cloud-resume-tf/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks" # Optional: DynamoDB for state locking (recommended)
    encrypt        = true
  }
}

# Add this resource block to your root configuration
resource "aws_dynamodb_table" "terraform_locks" {
  name             = "terraform-locks" # MUST MATCH the name in the backend block
  hash_key         = "LockID"
  billing_mode     = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "TerraformStateLockTable"
  }
}


module "backend" {
  source = "./modules/backend"
}

module "frontend" {
  source      = "./modules/frontend"
  domain_name = "example.com" # Placeholder: Terraform needs a value, even if commented out.
  api_url     = "https://3cugs71ej9.execute-api.us-east-1.amazonaws.com/visits" # YOUR actual API URL
}
