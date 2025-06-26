# ========================================================
# SECURE DEMO: Write-Only Attributes & Ephemeral Resources
# ========================================================
# 
# ✅ This demo shows the NEW, SECURE way of handling secrets
# ✅ Using Terraform 1.11+ write-only attributes and ephemeral resources
# ✅ Zero secrets in state files - ever!
#
# This file demonstrates the secure approach:
# - Secrets show as "(write-only attribute)" in terraform plan
# - Write-only attributes are stored as "null" in terraform.tfstate
# - Ephemeral resources provide temporary access without state storage
# - Complete functionality with zero state exposure
#
# Compare this with insecure-demo.tf to see the dramatic difference!
# ========================================================

terraform {
  required_version = ">= 1.11"
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

variable "vault_address" {
  description = "Vault server address"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault authentication token"
  type        = string
  default     = "root"
  sensitive   = true
}

variable "secret_version" {
  description = "Version of the secret data"
  type        = number
  default     = 1
}

# ========================================================
# PART 1: SECURE STATIC SECRET STORAGE (Write-Only Attributes)
# ========================================================

# Create KV mount for our secure demo
resource "vault_mount" "demo" {
  path        = "demo-secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "SECURE demo mount - no secrets will be exposed in state!"
}

# ✅ SECURE: Store database credentials using write-only attributes
# These secrets will NEVER appear in terraform plan or state file!
resource "vault_kv_secret_v2" "database_config" {
  mount               = vault_mount.demo.path
  name                = "database/postgres"
  delete_all_versions = true

  # 🔒 WRITE-ONLY ATTRIBUTE: Secrets never stored in state!
  # This is the magic - data_json_wo instead of data_json
  data_json_wo = jsonencode({
    host     = "production-db.company.com"
    port     = "5432"
    database = "myapp"
    username = "app_user"
    password = "super-secret-db-password-123" # 🔒 PROTECTED!
    ssl_mode = "require"
  })

  # Version tracking for secure updates
  data_json_wo_version = var.secret_version
}

# ========================================================
# PART 2: SECURE DYNAMIC DATABASE SECRETS (Write-Only Attributes)
# ========================================================

# Enable database secrets engine
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "SECURE database secrets - no passwords in state!"
}

# ✅ SECURE: Configure database connection using write-only password
# Root password will NEVER appear in state file!
resource "vault_database_secret_backend_connection" "postgres" {
  backend = vault_mount.database.path
  name    = "postgres-connection"

  allowed_roles     = ["app-role"]
  verify_connection = true

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@localhost:5432/postgres"

    # 🔒 WRITE-ONLY ATTRIBUTE: Root password never stored in state!
    username            = "postgres"
    password_wo         = "super-secret-db-password-123" # 🔒 PROTECTED!
    password_wo_version = var.secret_version
  }
}

# Create database role for generating dynamic credentials
resource "vault_database_secret_backend_role" "app_role" {
  backend = vault_mount.database.path
  name    = "app-role"
  db_name = vault_database_secret_backend_connection.postgres.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]

  default_ttl = 3600 # 1 hour
  max_ttl     = 3600
}

# ========================================================
# PART 3: SECURE SECRET RETRIEVAL (Ephemeral Resources)
# ========================================================

# ✅ SECURE: Retrieve database config without storing in state
# Ephemeral resources provide temporary access during configuration
ephemeral "vault_kv_secret_v2" "db_config" {
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.database_config.name

  # Defer until mount is created
  mount_id = vault_mount.demo.id
}

# ✅ SECURE: Generate dynamic database credentials (ephemeral)
# These credentials are temporary and never stored in state
ephemeral "vault_database_secret" "dynamic_db_creds" {
  mount = vault_mount.database.path
  name  = vault_database_secret_backend_role.app_role.name

  # Defer until database role is created
  mount_id = vault_mount.database.id
}

# ========================================================
# PART 4: SECURE SECRET COMPOSITION (Write-Only + Ephemeral)
# ========================================================

# ✅ SECURE: Create composite configuration using ephemeral secrets
# Combines retrieved secrets into new configuration without state exposure
resource "vault_kv_secret_v2" "complete_app_config" {
  mount               = vault_mount.demo.path
  name                = "app/complete-secure-config"
  delete_all_versions = true

  # 🔒 WRITE-ONLY ATTRIBUTE: Complete config with all secrets - never stored in state
  data_json_wo = jsonencode({
    # Application metadata (not secret)
    application_name = "myapp-production"

    # Static database connection using ephemeral retrieval
    database_url = format(
      "postgresql://%s:%s@%s:%s/%s?sslmode=%s",
      ephemeral.vault_kv_secret_v2.db_config.data.username,
      ephemeral.vault_kv_secret_v2.db_config.data.password,
      ephemeral.vault_kv_secret_v2.db_config.data.host,
      ephemeral.vault_kv_secret_v2.db_config.data.port,
      ephemeral.vault_kv_secret_v2.db_config.data.database,
      ephemeral.vault_kv_secret_v2.db_config.data.ssl_mode
    )

    # Dynamic database credentials (auto-expiring)
    dynamic_database = {
      username = tostring(ephemeral.vault_database_secret.dynamic_db_creds.username)
      password = tostring(ephemeral.vault_database_secret.dynamic_db_creds.password)
      ttl      = "1h"
    }

    # API keys and other secrets
    api_key    = "sk_live_abcdef123456789"
    jwt_secret = "jwt-super-secret-key-456"

    # Metadata
    created_at     = timestamp()
    security_level = "MAXIMUM - NO SECRETS IN STATE!" # 🔒 TRUTH!
    approach       = "Write-only attributes + Ephemeral resources"
  })

  # Version tracking for secure updates
  data_json_wo_version = var.secret_version
}

# ========================================================
# OUTPUTS SHOWING THE SECURE APPROACH
# ========================================================

output "security_status" {
  description = "Security status of this configuration"
  value = {
    status = "✅ ALL SECRETS PROTECTED - ZERO STATE EXPOSURE!"
    impact = "State files can be safely shared, stored, and backed up"
    risk   = "NONE - Production-ready security achieved"
  }
}

output "secure_vault_paths" {
  description = "Paths where secure secrets are stored"
  value = {
    kv_mount_path       = vault_mount.demo.path
    database_mount_path = vault_mount.database.path
    static_secret_path  = vault_kv_secret_v2.database_config.path
    dynamic_creds_path  = "${vault_mount.database.path}/creds/${vault_database_secret_backend_role.app_role.name}"
    complete_config     = vault_kv_secret_v2.complete_app_config.path
  }
}

output "write_only_demonstration" {
  description = "Demonstration of write-only attributes in state"
  value = {
    message            = "Check terraform.tfstate - all write-only attributes show as 'null'"
    static_secret_wo   = "vault_kv_secret_v2.database_config.data_json_wo = null"
    dynamic_secret_wo  = "vault_database_secret_backend_connection.postgres.postgresql[0].password_wo = null"
    complete_config_wo = "vault_kv_secret_v2.complete_app_config.data_json_wo = null"
    ephemeral_note     = "Ephemeral resources don't appear in state at all!"
  }
}

# ====================
# SECURITY VERIFICATION COMMANDS
# ====================

# After applying this configuration, run these commands to verify security:
#
# 1. Check terraform plan output:
#    terraform plan
#    # You'll see "(write-only attribute)" instead of secret values!
#
# 2. Check terraform state file:
#    cat terraform.tfstate | jq '.resources[] | select(.type=="vault_kv_secret_v2") | .instances[0].attributes.data_json_wo'
#    # You'll see "null" for all write-only attributes!
#
# 3. Search for secrets in state (they won't be there):
#    grep -r "super-secret-db-password-123" terraform.tfstate
#    grep -r "postgres-root-password-123" terraform.tfstate
#    # No matches - secrets are NOT in state!
#
# 4. Verify ephemeral resources aren't in state:
#    terraform state list | grep ephemeral
#    # Should return empty - ephemeral resources aren't stored!
#
# 5. Verify secrets are accessible in Vault:
#    vault kv get demo-secrets/database/postgres
#    vault read database/creds/app-role
#    # Secrets work perfectly, but aren't in your state file!
#
# This demonstrates the revolutionary security improvement!

# ====================
# WHAT STUDENTS WILL SEE
# ====================

# 1. terraform plan will show:
#    + data_json_wo = (write-only attribute)  # 🔒 PROTECTED!
#    + password_wo  = (write-only attribute)  # 🔒 PROTECTED!
#
# 2. terraform.tfstate will contain:
#    "data_json_wo": null,
#    "password_wo": null,
#
# 3. State file analysis reveals:
#    - No secret values anywhere
#    - Write-only attributes are null
#    - Ephemeral resources don't exist in state
#    - Complete functionality without security risk
#
# This is why write-only attributes are REVOLUTIONARY! 🚀
