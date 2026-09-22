variable kubernetes_endpoint {
  default     =  "https://kubernetes.docker.internal:6443"
  type        = string
  description = "Kubernetes/Openshift Endpoint" 
}

# Vault Version
variable "vault_version" {
  type = string
  description = "Vault Version"
  default = "1.19-ent"
}

variable "vault_license" {
  type = string
  description = "Vault License"
  default = ""
}

# Vault Sidecar Injector Version
variable "vault_helm_version" {
  type = string
  description = "Vault's Helm Release Version"
  default = "0.32.0"
}

# Vault Secret Operator Version
variable "vso_helm_version" {
  type = string
  description = "Vault Secret Operator Helm Release Version"
  default = "1.3.0"
}


variable vault_public_address {
  type        = string
  default     = "http://vault.vault.svc.cluster.local:8200"
  description = "Vault Address e.g https://vault.example.com" 
}

variable vault_namespace {
  type        = string
  default     = "root"
  description = "Vault Namespace" 
}

variable vault_admin_token {
  type        = string
  default     = "root"
  description = "Vault Token" 
}

variable kubernetes_namespace {
  type        = string
  default     = "default"
  description = "Kubernetes Namespace" 
}

# Promethues Stack Helm Version
variable "prom_version" {
  type = string
  description = "Prom Version"
  default = "68.4.0"
}

# JWKS object from GET /v1/spiffe/trust_bundle/web. Required for SPIFFE
# auth (profile = static). Refresh after the secrets engine rotates keys.
# This is a workaround I used as I was having issues with fetching the trust bundle from the secrets engine due to the HTTP-only listener.
variable "static_bundle" {
  type        = any
  description = "SPIFFE trust bundle (JWKS) copied from the secrets engine into auth-spiffe"
  default     = {}
}








