# Uncomment to deploy the Vault Benchmark tool
resource "kubernetes_config_map" "config" {
  metadata {
    name = "benchmark"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  data = {
    "benchmark.hcl" = file("benchmark.hcl")
  }
}

# Benchmark Job
resource "kubernetes_job" "benchmark" {
  depends_on = [helm_release.vault,time_sleep.wait]
  metadata {
    name = "benchmark"
    namespace = kubernetes_namespace.vault.metadata[0].name
  }
  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "benchmark"
          image   = "hashicorp/vault-benchmark"
          command = ["vault-benchmark","run","-config=/opt/vault-benchmark/configs/benchmark.hcl"]
          volume_mount {
                mount_path = "/opt/vault-benchmark/configs/"
                name = "config"
            }
        }
        restart_policy = "OnFailure"
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.config.metadata.0.name
          }
      }
    }
  }
}
wait_for_completion = false
}
