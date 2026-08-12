# Secrets live here in Parameter Store and are injected into containers
# via ECS `secrets` blocks (never as plaintext env vars in the task def).
# All values are write-only: tofu sends them to SSM without storing them
# in the state file.

resource "aws_ssm_parameter" "tailscale_auth" {
  name             = "/${local.name}/tailscale-auth-key"
  description      = "Tailscale auth key for the ECS sidecar node"
  type             = "SecureString"
  value_wo         = var.tailscale_auth_key
  value_wo_version = 1
}

resource "aws_ssm_parameter" "admin_password" {
  name             = "/${local.name}/admin-password"
  description      = "Copyparty admin account password"
  type             = "SecureString"
  value_wo         = random_password.admin.result
  value_wo_version = 1
}

resource "aws_ssm_parameter" "consumer_password" {
  name             = "/${local.name}/consumer-password"
  description      = "Copyparty consumer account password"
  type             = "SecureString"
  value_wo         = random_password.consumer.result
  value_wo_version = 1
}
