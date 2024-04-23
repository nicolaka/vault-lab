# Vault Auth Methods & Roles Configuration

# Creating userpass auth method in root namespace
resource "vault_auth_backend" "userpass" {
  namespace = var.vault_namespace
  type = "userpass"
  path = "userpass"

  tune {
    max_lease_ttl      = "90000s"
    listing_visibility = "unauth"
  }
}

# Creating AppRole Auth Method & Roles in the Root Namespace
resource "vault_auth_backend" "approle" {
  namespace = var.vault_namespace
  type = "approle"
}


# LDAP AUTH in Root Namespace
resource "vault_ldap_auth_backend" "root_ldap" {
  namespace = var.vault_namespace
  path = "ldap"
  binddn = "cn=vault-bind,cn=Users,dc=hashicorp,dc=com" 
  bindpass="P@ssword1" 
  url= "ldaps://ldap:636" 
  userdn="dc=hashicorp,dc=com" 
  userattr="sAMAccountName" 
  groupdn="cn=Users,dc=hashicorp,dc=com" 
  groupattr="cn" 
  username_as_alias="true" 
  insecure_tls="true"
}


# Creating users in the userpass auth backend
resource "vault_generic_endpoint" "alice" {
  namespace            = var.vault_namespace
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/alice"
  ignore_absent_fields = true
  data_json = <<EOT
{
  "policies": ["default"],
  "password": "P@ssword1"
}
EOT
}

resource "vault_generic_endpoint" "bob" {
  namespace            = var.vault_namespace
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/bob"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["default"],
  "password": "P@ssword1"
}
EOT
}

resource "vault_generic_endpoint" "dave" {
  namespace            = var.vault_namespace
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/dave"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["default"],
  "password": "P@ssword1"
}
EOT
}

# Creating Approle Role for App A

resource "vault_approle_auth_backend_role" "app_a" {
  backend        = vault_auth_backend.approle.path
  role_name      = "app_a_role"
  token_policies = ["blue"]
}

resource "vault_approle_auth_backend_role" "app_b" {
  backend        = vault_auth_backend.approle.path
  role_name      = "app_b_role"
  token_policies = ["red"]
}


# Kubernetes Auth Method & Roles
data "kubernetes_service_account" "vault_auth" {
  depends_on = [helm_release.vault]
  metadata {
    name = "vault"
    namespace  = kubernetes_namespace.vault.id
  }
}

resource "kubernetes_secret" "vault_auth" {
  depends_on = [helm_release.vault]
  metadata {
    name = "vault"
    namespace  = kubernetes_namespace.vault.id
    annotations = {
      "kubernetes.io/service-account.name" = data.kubernetes_service_account.vault_auth.metadata.0.name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "vault_auth_backend" "kubernetes" {
  path      = "kubernetes"
  namespace = var.vault_namespace
  depends_on = [helm_release.vault]
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  depends_on             = [helm_release.vault]
  namespace             =  var.vault_namespace
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_endpoint
  kubernetes_ca_cert     = kubernetes_secret.vault_auth.data["ca.crt"]
  token_reviewer_jwt     = kubernetes_secret.vault_auth.data.token
  disable_iss_validation = "true"
}

# Creating a K8s Auth Role for App A which will be used by VSO Deployment
resource "vault_kubernetes_auth_backend_role" "app_a" {
  namespace                        = var.vault_namespace
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "app_a"
  bound_service_account_names      = ["default"]
  alias_name_source                = "serviceaccount_name"
  #alias_name_source                = "serviceaccount_uid" # Service Account UUID is another option
  bound_service_account_namespaces = [kubernetes_namespace.blue.id]
  token_ttl                        = 3600
  token_policies                   = ["blue"]
  audience                         = ""
}

# Creating a K8s Auth Role for App B which will be used by SideCar Injector
resource "vault_kubernetes_auth_backend_role" "app_b" {
  namespace                        = var.vault_namespace
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "app_b"
  bound_service_account_names      = ["default"]
  alias_name_source                = "serviceaccount_uid"
  bound_service_account_namespaces = [kubernetes_namespace.red.id]
  token_ttl                        = 3600
  token_policies                   = ["red"]
  audience                         = ""
}