
# Authenticating and doing an Entity Lookup 
resource "vault_generic_endpoint" "bob_token" {
  depends_on     = [vault_generic_endpoint.bob]
  path           = "auth/userpass/login/bob"
  disable_read   = true
  disable_delete = true

  data_json = <<EOT
{
  "password": "P@ssword1"
}
EOT
}

resource "vault_generic_endpoint" "alice_token" {
  depends_on     = [vault_generic_endpoint.alice]
  path           = "auth/userpass/login/alice"
  disable_read   = true
  disable_delete = true

  data_json = <<EOT
{
  "password": "P@ssword1"
}
EOT
}

resource "vault_generic_endpoint" "dave_token" {
  depends_on     = [vault_generic_endpoint.dave]
  path           = "auth/userpass/login/dave"
  disable_read   = true
  disable_delete = true

  data_json = <<EOT
{
  "password": "P@ssword1"
}
EOT
}

resource "vault_generic_endpoint" "bob_entity" {
  depends_on           = [vault_generic_endpoint.bob_token]
  disable_read         = true
  disable_delete       = true
  path                 = "identity/lookup/entity"
  ignore_absent_fields = true
  write_fields         = ["id"]

  data_json = <<EOT
{
  "alias_name": "bob",
  "alias_mount_accessor": "${vault_auth_backend.userpass.accessor}"
}
EOT
}

resource "vault_generic_endpoint" "alice_entity" {
  depends_on           = [vault_generic_endpoint.alice_token]
  disable_read         = true
  disable_delete       = true
  path                 = "identity/lookup/entity"
  ignore_absent_fields = true
  write_fields         = ["id"]

  data_json = <<EOT
{
  "alias_name": "alice",
  "alias_mount_accessor": "${vault_auth_backend.userpass.accessor}"
}
EOT
}

resource "vault_generic_endpoint" "dave_entity" {
  depends_on           = [vault_generic_endpoint.dave_token]
  disable_read         = true
  disable_delete       = true
  path                 = "identity/lookup/entity"
  ignore_absent_fields = true
  write_fields         = ["id"]

  data_json = <<EOT
{
  "alias_name": "dave",
  "alias_mount_accessor": "${vault_auth_backend.userpass.accessor}"
}
EOT
}

## Approle Authentication
resource "vault_approle_auth_backend_role_secret_id" "app_a" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.app_a.role_name
}

resource "vault_approle_auth_backend_login" "app_a_login" {
  backend   = vault_auth_backend.approle.path
  role_id   = vault_approle_auth_backend_role.app_a.role_id
  secret_id = vault_approle_auth_backend_role_secret_id.app_a.secret_id
}

resource "vault_approle_auth_backend_role_secret_id" "app_b" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.app_b.role_name
}


resource "vault_approle_auth_backend_login" "app_b_login" {
  backend   = vault_auth_backend.approle.path
  role_id   = vault_approle_auth_backend_role.app_b.role_id
  secret_id = vault_approle_auth_backend_role_secret_id.app_b.secret_id
}


output "bob_pre_created_entity_id" {
  value = try(vault_identity_entity.bob.id,[])
}

output "bob_entity_lookup_id" {
  value = try(vault_generic_endpoint.bob_entity.write_data["id"],[])
}

output "alice_pre_created_entity_id" {
  value = try(vault_identity_entity.alice.id,[])
}

output "alice_entity_lookup_id" {
  value = try(vault_generic_endpoint.alice_entity.write_data["id"],[])
}


output "dave_entity_lookup_id" {
  value = try(vault_generic_endpoint.dave_entity.write_data["id"],[])
}



