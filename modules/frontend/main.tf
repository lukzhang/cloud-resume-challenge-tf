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
resource "aws_s3_bucket_policy" "content" {
  bucket = aws_s3_bucket.content.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.content.arn}/*"
      }
    ]
  })
}


# 3. CLOUDFRONT DISTRIBUTION (CDN for HTTPS)
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.content.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.content.id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ADD THIS BLOCK to satisfy the requirement
  viewer_certificate {
    cloudfront_default_certificate = true
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


# TEMPORARILY COMMENTED OUT: We are skipping DNS (Route 53) until a domain is purchased.
/*
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
*/