# Creating User Entities
resource "vault_identity_entity" "bob" {
  name      = "bob"
  policies  = ["blue"]
  metadata  = {
    user = "bob"
    team = "blue"
  }
}

resource "vault_identity_entity" "alice" {
  name      = "alice"
  policies  = ["red"]
  metadata  = {
    user = "alice"
    team = "red"
  }
}

/* Intentionally not creating an Entity for Dave
resource "vault_identity_entity" "dave" {
  name      = "dave"
  policies  = ["red"]
  metadata  = {
    user = "dave"
    team = "red"
  }
}
*/


# Creating LDAP User Aliases
resource "vault_identity_entity_alias" "bob_ldap_alias" {
  name            = "bob" 
  mount_accessor  = vault_ldap_auth_backend.root_ldap.accessor
  canonical_id    = vault_identity_entity.bob.id
  custom_metadata = {
    username = "bob"
    email  = "bob@hashicorp.com"
  }
}

resource "vault_identity_entity_alias" "bob_userpass_alias" {
  name            = "bob" 
  mount_accessor  = vault_auth_backend.userpass.accessor
  canonical_id    = vault_identity_entity.bob.id
  custom_metadata = {
    username = "bob"
    email  = "bob@hashicorp.com"
  }
}


# We're only creating an ldap alias for Alice intentionally. 
resource "vault_identity_entity_alias" "alice_ldap_alias" {
  name            = "alice" 
  mount_accessor  = vault_ldap_auth_backend.root_ldap.accessor
  canonical_id    = vault_identity_entity.alice.id
  custom_metadata = {
    username = "alice"
    email  = "alice@hashicorp.com"
  }
}


# Kubernetes Entities/Aliases
data "kubernetes_service_account" "blue_default" {
  metadata {
    name = "default"
    namespace = "${kubernetes_namespace.blue.id}"
  }
}

data "kubernetes_service_account" "red_default" {
  metadata {
    name = "default"
    namespace = "${kubernetes_namespace.red.id}"
  }
}


# Creating Application Entities
resource "vault_identity_entity" "app_a" {
  name      = "app_a"
  policies  = ["blue"]
  metadata  = {
    app = "a"
  }
}

resource "vault_identity_entity_alias" "app_a_approle_alias" {
  name            = vault_approle_auth_backend_role.app_a.role_id
  mount_accessor  = vault_auth_backend.approle.accessor
  canonical_id    = vault_identity_entity.app_a.id
  custom_metadata = {
    app = "app_a"
    auth = "approle"
  }
}


resource "vault_identity_entity_alias" "app_a_k8s_alias" {
  name            = "${data.kubernetes_service_account.blue_default.metadata[0].namespace}/${data.kubernetes_service_account.blue_default.metadata[0].name}"
  #name            = "${data.kubernetes_service_account.blue_default.metadata[0].uid}"
  mount_accessor  = vault_auth_backend.kubernetes.accessor
  canonical_id    = vault_identity_entity.app_a.id
  custom_metadata = {
    app = "app_a"
    auth = "k8s"
  }
}

# Creating Application Entities
resource "vault_identity_entity" "app_b" {
  name      = "app_b"
  policies  = ["red"]
  metadata  = {
    app = "red"
  }
}



resource "vault_identity_entity_alias" "app_b_approle_alias" {
  name            = vault_approle_auth_backend_role.app_b.role_id
  mount_accessor  = vault_auth_backend.approle.accessor
  canonical_id    = vault_identity_entity.app_b.id
  custom_metadata = {
    app = "app_b"
    auth = "approle"
  }
}


resource "vault_identity_entity_alias" "app_b_k8s_alias" {
  name            = "${data.kubernetes_service_account.red_default.metadata[0].uid}"
  mount_accessor  = vault_auth_backend.kubernetes.accessor
  canonical_id    = vault_identity_entity.app_b.id
  custom_metadata = {
    app = "app_b"
    auth = "k8s"
  }
}


