# Basic Benchmark config options
vault_addr = "http://vault.vault.svc.cluster.local:8200"
vault_token = "root"
vault_namespace="root"
duration = "60s"
random_mounts = true
#cleanup = true

test "approle_auth" "approle_logins" {
  weight = 25
  config {
    role {
      role_name = "benchmark-role"
      bind_secret_id    = true
      token_ttl="2m"
      token_num_uses=1
    }
  }
}

test "userpass_auth" "userpass_test1" {
    weight = 25
    config {
        username = "bob"
        password = "P@ssword1"
    }
}

test "kvv2_write" "static_secret_writes" {
  weight = 25
  config {
    numkvs = 100
    kvsize = 100
  }
}

test "kvv2_read" "static_secret_reads" {
  weight = 25
  config {
    numkvs = 100
  }
}
