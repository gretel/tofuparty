resource "random_password" "admin" {
  length  = var.password_length
  special = false
}

resource "random_password" "consumer" {
  length  = var.password_length
  special = false
}
