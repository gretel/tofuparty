resource "random_password" "admin" {
  length  = var.password_length
  special = false
}

resource "random_password" "consumer" {
  length  = var.password_length
  special = false
}

resource "aws_ssm_parameter" "tailscale_auth" {
  name        = "/${local.name}/tailscale-auth-key"
  description = "Tailscale auth key for the ECS sidecar node"
  type        = "SecureString"
  value       = var.tailscale_auth_key

  # Rotate in the console/CLI without tofu touching it
  lifecycle {
    ignore_changes = [value]
  }
}
