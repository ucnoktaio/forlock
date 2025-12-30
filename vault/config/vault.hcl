# Forlock Vault Configuration
# Production-ready configuration

ui = true
disable_mlock = false
cluster_name = "forlock-vault"

# Storage backend - Raft (recommended for HA)
storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"

  # For HA cluster, add retry_join blocks:
  # retry_join {
  #   leader_api_addr = "https://vault-2:8200"
  # }
}

# Listener configuration
listener "tcp" {
  address       = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"

  # TLS Configuration (enable in production)
  tls_disable = true
  # tls_cert_file = "/vault/config/tls/vault.crt"
  # tls_key_file  = "/vault/config/tls/vault.key"
  # tls_min_version = "tls12"
}

# API address - update with your domain
api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"

# Telemetry for monitoring
telemetry {
  disable_hostname = true
  prometheus_retention_time = "12h"
}

# Default lease TTL
default_lease_ttl = "1h"
max_lease_ttl = "24h"

# Log level
log_level = "info"
