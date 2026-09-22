# Creating two kv secret engines , one in blue ns and one in red namespace
resource "vault_mount" "blue_kvv2" {
  depends_on = [ helm_release.vault, vault_namespace.blue ]
  namespace = kubernetes_namespace.blue.id
  path        = "kv"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount for static credential injection"
}

resource "vault_kv_secret_backend_v2" "blue_kvv2" {
  depends_on = [ helm_release.vault, vault_namespace.blue ]
  namespace            = kubernetes_namespace.blue.id
  mount                = vault_mount.blue_kvv2.path
  max_versions         = 5
  #delete_version_after = 12600
  cas_required         = false
}


# Sample secrets 
resource "vault_kv_secret_v2" "blue_app_secret" {
  namespace                  = kubernetes_namespace.blue.id
  mount                      = vault_mount.blue_kvv2.path
  name                       = "app/config"
  cas                        = 1
  #delete_all_versions        = true
  data_json                  = jsonencode(
    {
      username       = "demo",
      password       = "blue"
    }
  )
}

resource "vault_mount" "red_kvv2" {
  depends_on = [ helm_release.vault, vault_namespace.red ]
  namespace = vault_namespace.red.path
  path        = "kv"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount for static credential injection"
}

resource "vault_kv_secret_backend_v2" "red_kvv2" {
  depends_on = [ helm_release.vault, vault_namespace.red ]
  namespace = vault_namespace.red.path
  mount                = vault_mount.red_kvv2.path
  max_versions         = 5
  #delete_version_after = 12600
  cas_required         = false
}

# Sample secrets 
resource "vault_kv_secret_v2" "red_app_secret" {
  namespace = vault_namespace.red.path
  mount                      = vault_mount.red_kvv2.path
  name                       = "app/config"
  cas                        = 1
  #delete_all_versions        = true
  data_json                  = jsonencode(
  {
    username       = "demo",
    password       = "red"
  }
  )
}


# SPIFFE Secret Engine

resource "vault_mount" "spiffe" {
  depends_on  = [helm_release.vault]
  namespace   = var.vault_namespace
  path        = "spiffe"
  type        = "spiffe"
  description = "SPIFFE secrets engine for workload identity via JWT SVIDs"
}

resource "vault_spiffe_secret_backend_config" "spiffe" {
  mount                       = vault_mount.spiffe.path
  namespace                   = var.vault_namespace
  trust_domain                = "example.org"
  jwt_signing_algorithm       = "RS256"
  jwt_oidc_compatibility_mode = false
}

resource "vault_spiffe_secret_backend_role" "app_a" {
  namespace     = var.vault_namespace
  mount         = vault_mount.spiffe.path
  name          = "app-a"
  template      = jsonencode({ sub = "spiffe://example.org/ns/blue/sa/app-a" })
  ttl           = "1h"
  use_jti_claim = true
}

resource "vault_spiffe_secret_backend_role" "app_b" {
  mount         = vault_mount.spiffe.path
  namespace     = var.vault_namespace
  name          = "app-b"
  template      = jsonencode({ sub = "spiffe://example.org/ns/red/sa/app-b" })
  ttl           = "1h"
  use_jti_claim = true
}

resource "vault_policy" "spiffe_app_a" {
  namespace = var.vault_namespace
  name      = "spiffe-app-a"
  policy    = <<EOT
path "spiffe/trust_bundle/web" {
  capabilities = ["read"]
}

path "spiffe/role/app-a/mintjwt" {
  capabilities = ["create", "update"]
}
EOT
}

resource "vault_policy" "spiffe_app_b" {
  namespace = var.vault_namespace
  name      = "spiffe-app-b"
  policy    = <<EOT
path "spiffe/trust_bundle/web" {
  capabilities = ["read"]
}

path "spiffe/role/app-b/mintjwt" {
  capabilities = ["create", "update"]
}
EOT
}
