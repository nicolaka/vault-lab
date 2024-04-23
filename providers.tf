terraform {
 required_version = "~> 1.5"
 required_providers {
        vault = {
            source  = "hashicorp/vault"
            version =  "~> 3.25.0"
        }
        helm = {
            source  = "hashicorp/helm"
            version = "~> 2.12.1"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = "~> 2.25.2"
        }
    }
}

data "kubernetes_service" "vault" {
  depends_on = [ helm_release.vault ]
  metadata {
    name = "vault"
    namespace = kubernetes_namespace.vault.id
  }
}

provider "vault" {
  skip_child_token = true
  # If you're running Terraform natively on your Mac use http://localhost:30001 (uncommment below)
  #address = "http://localhost:30001" 
  # If you're running Terraform in a container on your mac, use http://${data.kubernetes_service.vault.spec.0.cluster_ip}:8200 (uncomment below)
  address = "http://${data.kubernetes_service.vault.spec.0.cluster_ip}:8200"
  token = var.vault_admin_token
} 

provider "kubernetes" {
  config_path           = "~/.kube/config"
  config_context        = "docker-desktop"
}


provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "docker-desktop"
  }
}


