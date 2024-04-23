# Deploying Vault Helm Chart, VSO, LDAP 
# Creating Vault Enterprise License Secret
resource "kubernetes_secret_v1" "vault_license" {
  metadata {
    name = "vaultlicense"
    namespace  = kubernetes_namespace.vault.id
  }

  data = {
    license = var.vault_license
  }

  type = "kubernetes.io/opaque"
}

resource "kubernetes_config_map" "vaultconfig" {
  metadata {
    name = "vaultconfig"
    namespace  = kubernetes_namespace.vault.id
  }
  data = {
    "vault.hcl" = "${file("vault.hcl")}"
  }
}

# Deploying sidecar injector helm chart
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.id
  version    = var.vault_helm_version
  values = [
    "${file("values.vault.yml")}"
  ]
}

# Deploying VSO
resource "helm_release" "vso" {
  depends_on = [ helm_release.vault ]
  name       = "vso"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  namespace  = kubernetes_namespace.vault.id
  version    = var.vso_helm_version

  set {
    name  = "defaultVaultConnection.enabled"
    value = "true"
  }

  set {
    name  = "defaultVaultConnection.address"
    value = "http://${data.kubernetes_service.vault.spec.0.cluster_ip}:8200"
  }

  set {
    name  = "defaultVaultConnection.skipTLSVerify"
    value = "true"
  }
  
  set {
    name  = "defaultAuthMethod.enabled"
    value = "true"
  }

  set {
    name  = "defaultAuthMethod.namespace"
    value = var.vault_namespace
  }

  set {
    name  = "defaultAuthMethod.method"
    value = "kubernetes"
  }

  set {
    name  = "defaultAuthMethod.mount"
    value = "kubernetes"
  }

  set {
    name  = "defaultAuthMethod.kubernetes.role"
    value = "default"
  }

  set {
    name  = "defaultAuthMethod.kubernetes.serviceaccount"
    value = "default"
  }

  set_list {
    name  = "defaultAuthMethod.kubernetes.tokenAudiences"
    value = ["vault"]
  }
}

# Waiting 60s to allow VSO CRDs to be created before proceeding with k8s deployments that reference them
resource "time_sleep" "wait" {
  depends_on = [helm_release.vso]
  create_duration = "60s"
}


# Important Note ###
# The below two deployments "blue-vault-connection-default" and "blue-vault-auth-default" require VSO CRD to be installed
# First before you can run a Terraform Plan or Apply. Therefore it's required for you to comment these two resources out, run Terraform apply, then uncomment
# Them and run Terraform one more time! 
# VSO Kuberneters Connections
resource "kubernetes_manifest" "blue-vault-connection-default" {
  depends_on = [time_sleep.wait]
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.blue.metadata[0].name
    }
    spec = {
      address = "http://vault.vault.svc.cluster.local:8200"
    }
  }

  field_manager {
    # force field manager conflicts to be overridden
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "blue-vault-auth-default" {
  depends_on = [time_sleep.wait]
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.blue.metadata[0].name
    }
    spec = {
      method    = "kubernetes"
      namespace = vault_auth_backend.kubernetes.namespace
      mount     = vault_auth_backend.kubernetes.path
      kubernetes = {
        role           = vault_kubernetes_auth_backend_role.app_a.role_name
        serviceAccount = "default"
        audiences = [
          "vault",
        ]
      }
    }
  }
}


## Deploying LDAP 
resource "kubernetes_deployment" "ldap" {
  metadata {
    name      = "ldap"
    namespace = kubernetes_namespace.vault.metadata[0].name
    labels = {
      app = "ldap"
    }
  }


  spec {
    replicas = 1

    strategy {
      rolling_update {
        max_unavailable = "1"
      }
    }

    selector {
      match_labels = {
        app = "ldap"
      }
    }

    template {
      metadata {
        labels = {
          app = "ldap"
        }
      }

      spec {
        container {
          image = "nicolaka/samba-domain:1.0"
          name  = "ldap"

          env {
            name = "DOMAIN"
            value = "hashicorp.com"
          }
          env {
            name = "DOMAINPASS"
            value = "P@ssword1"
          }

          env {
            name = "INSECURELDAP"
            value = "true"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "ldap" {
  metadata {
    name = "ldap"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  spec {
    selector = {
      app = "ldap"
    }
    session_affinity = "ClientIP"
    port {
      name        = "ldap-389"
      port        = 389
      target_port = 389
    }

    port {
      name        = "ldap-636"
      port        = 636
      target_port = 636
    }

    type = "ClusterIP"  
  }
}


## Configuring Vault Audit Logging
resource "vault_audit" "local" {
  depends_on = [ vault_namespace.red ]
  type  = "file"
  path  = "audit"
  local = true
  options = {
    file_path = "/tmp/vault.log"
    log_raw = true
  }
}

