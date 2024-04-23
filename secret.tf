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


