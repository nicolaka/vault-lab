telemetry {
  disable_hostname = true
  enable_hostname_label = true
  prometheus_retention_time = "30s"
}

reporting {
  snapshot_retention_time = 9600
  disable_product_usage_reporting = false
  license {
    enabled = true
   # billing_start_timestamp = "2024-07-01T00:00:00Z"
  }
}