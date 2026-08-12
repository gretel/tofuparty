# Secret values that are generated, not provided. They're written into
# Parameter Store (see ssm.tf) and injected into containers via ECS secrets.
resource "random_password" "admin" {
  length  = var.password_length
  special = false
}

resource "random_password" "consumer" {
  length  = var.password_length
  special = false
}
