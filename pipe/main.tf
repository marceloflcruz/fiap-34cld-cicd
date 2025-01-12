provider "aws" {
  region = "us-east-1" # Substitua pela sua região
}

resource "aws_s3_bucket" "pipeline_bucket" {
  bucket = "cld34-devops-final-pipeline-bucket"
  tags = {
    Name        = "Pipeline-Bucket"
    Environment = "DevOps"
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_bucket_public_access" {
  bucket = aws_s3_bucket.pipeline_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}