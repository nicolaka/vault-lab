# Monitoring Stack
# Deploying sidecar injector helm chart
resource "helm_release" "prometheus" {
  depends_on = [ helm_release.vault ]
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.vault.id
  #version    = var.vault_helm_version


  values = [
    "${file("prom.stack.values.yml")}"
  ]
}

resource "kubernetes_secret_v1" "vault_token" {
  metadata {
    name = "vaulttoken"
    namespace  = kubernetes_namespace.vault.id
  }

  data = {
    token = var.vault_admin_token
  }

  type = "kubernetes.io/opaque"
}


resource "kubernetes_config_map" "grafana-dashboards-vault" {
  metadata {
    name      = "grafana-dashboard-vault"
    namespace = kubernetes_namespace.vault.id

    labels = {
      grafana_dashboard = 1
    }

    annotations = {
      k8s-sidecar-target-directory = "/tmp/dashboards/vault"
    }
  }

  data = {
    "vault.grafana.json"        = file("vault.grafana.json")
  }
}