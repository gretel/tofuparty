output "cloudfront_url" {
  description = "HTTPS URL to access copyparty (TLS via CloudFront default cert)"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "admin_login" {
  description = "Login credentials (URL and password)"
  sensitive   = true
  value = {
    url      = "https://${aws_cloudfront_distribution.this.domain_name}"
    username = "admin"
    password = random_password.admin.result
  }
}

output "alb_url" {
  description = "ALB URL (HTTP only, for debugging)"
  value       = "http://${aws_lb.this.dns_name}"
}

output "consumer_login" {
  description = "Consumer login credentials"
  sensitive   = true
  value = {
    url      = "https://${aws_cloudfront_distribution.this.domain_name}"
    username = "consumer"
    password = random_password.consumer.result
  }
}
