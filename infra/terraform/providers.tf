terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure this block to enable remote S3 state backend.
  # Remote state is required to satisfy the brief, but must be configured with your bucket.
  # backend "s3" {
  #   bucket         = "your-phoenix-capstone-tf-state-bucket"
  #   key            = "state/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-phoenix-capstone-tf-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region
}
