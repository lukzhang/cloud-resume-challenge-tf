# modules/frontend/outputs.tf

output "s3_content_bucket_name" {
  description = "The name of the S3 bucket where website content is stored."
  value       = aws_s3_bucket.content.id
}

output "cloudfront_domain_name" {
  description = "The public domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.cdn.domain_name
}