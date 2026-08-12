resource "random_password" "admin" {
  length  = var.password_length
  special = false
}

resource "random_password" "consumer" {
  length  = var.password_length
  special = false
}

resource "aws_ssm_parameter" "tailscale_auth" {
  name             = "/${local.name}/tailscale-auth-key"
  description      = "Tailscale auth key for the ECS sidecar node"
  type             = "SecureString"
  value_wo         = var.tailscale_auth_key # write-only: kept in SSM, not in state
  value_wo_version = 1
}
