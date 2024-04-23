resource "vault_policy" "blue" {
  namespace = var.vault_namespace
  name = "blue"
  policy = <<EOT
path "blue/kv/data/app/config" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "red" {
  namespace = var.vault_namespace
  name = "red"
  policy = <<EOT
path "red/kv/data/app/config" {
  capabilities = ["read"]
}
EOT
}