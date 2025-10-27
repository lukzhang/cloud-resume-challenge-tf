# modules/frontend/main.tf

# 1. S3 BUCKET FOR CONTENT (Static Website Hosting)
resource "aws_s3_bucket" "content" {
  bucket = "luke-resume-website-content" # Choose a globally unique name!
  
  
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# 2. S3 BUCKET POLICY (Allows CloudFront/Public Access)
# resource "aws_s3_bucket_policy" "content" {
#   bucket = aws_s3_bucket.content.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "PublicReadGetObject",
#         Effect    = "Allow",
#         Principal = "*",
#         Action    = "s3:GetObject",
#         Resource  = "${aws_s3_bucket.content.arn}/*"
#       }
#     ]
#   })
# }

# Data source for an IAM policy document
data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.my_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      # 🚨 Crucial: This condition enforces that only YOUR distribution can access the bucket
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.my_cdn.arn]
    }
  }

  # Add a second statement to allow the root object (index.html, etc.) to be listed
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.my_bucket.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.my_cdn.arn]
    }
  }
}

# Attach the policy to the S3 bucket
resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = data.aws_iam_policy_document.s3_access_policy.json
}


# 3. CLOUDFRONT DISTRIBUTION (CDN for HTTPS)
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  # origin {
  #   domain_name              = aws_s3_bucket.content.bucket_regional_domain_name
  #   origin_id                = aws_s3_bucket.content.id
  #   custom_origin_config {
  #     http_port              = 80
  #     https_port             = 443
  #     origin_protocol_policy = "http-only"
  #     origin_ssl_protocols   = ["TLSv1.2"]
  #   }
  # }

  # 1. ORIGIN BLOCK: Use the S3 bucket's domain name, NOT the static website URL.
  # The origin should reference the OAC you created.
  origin {
    domain_name = aws_s3_bucket.luke-resume-website-content
    origin_id   = "S3-${aws_s3_bucket.my_bucket.id}"
    
    # 🚨 Crucial: Specify the Origin Access Control ID (OAC)
    # The OAC is the modern, recommended way to secure S3 origins.
    # If you are using Origin Access Identity (OAI), this field will be s3_origin_config.
    # The plan suggests it's looking for OAC:
    origin_access_control_id = aws_cloudfront_origin_access_control.E2G7EEWNZXXOX0
  }

  # 2. ALIASES: Your custom domain name must be here.
  aliases = [
    "www.luke-zhang-aws.com",  # Re-add your CNAME
  ]

  # 3. VIEWER CERTIFICATE: Use your custom ACM certificate.
  viewer_certificate {
    # 🚨 Crucial: Re-add your ACM Certificate ARN and remove cloudfront_default_certificate
    acm_certificate_arn      = "arn:aws:acm:us-east-1:961657839676:certificate/67e483da-5cdc-4c19-84c7-c7888ee06afa"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021" # Or your desired version
    
    # Ensure 'cloudfront_default_certificate' is NOT here or is set to false
    # cloudfront_default_certificate = false 
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.content.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    
    # Configure caching behavior to forward API responses
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }
  
  # TEMPORARILY COMMENTED OUT: DNS configuration requires a domain.
  /*
  aliases = [var.domain_name]

  viewer_certificate {
    cloudfront_default_certificate = true
    # If using a custom certificate later:
    # acm_certificate_arn = aws_acm_certificate.cert.arn
    # ssl_support_method = "sni-only"
  }
  */

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "my_oac" {
  name                          = "my-cdn-oac"
  description                   = "OAC for private S3 access"
  origin_access_control_origin_type = "s3"
  signing_behavior              = "always"
  signing_protocol              = "sigv4"
}


resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name # This record is for the root domain (e.g., example.com)
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}