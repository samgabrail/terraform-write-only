# Complete Terraform Write-Only Secrets Demo
# 
# This demo showcases TWO types of secrets management:
#
# 🔐 STATIC SECRETS (KV Store):
# 1. Storing secrets in Vault using write-only attributes (secrets never in state)
# 2. Retrieving secrets from Vault using ephemeral resources (secrets never in state)
# 3. Composing complex configurations using both features together
#
# 🔄 DYNAMIC SECRETS (Database Engine):
# 4. Configuring Vault to generate temporary database credentials
# 5. Using ephemeral resources to get short-lived DB credentials (auto-expiring)
# 6. Complete infrastructure setup for dynamic secrets (requires real database)

terraform {
  required_version = ">= 1.11" # Tested with v1.12.1
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 5.0" # Tested with Vault v1.18.4
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
  default     = "http://localhost:8200"
}

variable "vault_token" {
  description = "Vault authentication token"
  type        = string
  sensitive   = true
  default     = "root"
}

variable "secret_version" {
  description = "Version of the secret data for tracking updates"
  type        = number
  default     = 1
}

# ==============================================
# PART 1: STORING SECRETS (Write-Only Demo)
# ==============================================

# Create a KV v2 mount for our demo
resource "vault_mount" "demo" {
  path = "demo-secrets"
  type = "kv"
  options = {
    version = "2"
  }
  description = "Demo mount for write-only attributes"
}

# Store database credentials using write-only attributes
# 🔒 These secrets will NEVER appear in terraform.tfstate
resource "vault_kv_secret_v2" "database_config" {
  mount = vault_mount.demo.path
  name  = "database/postgres"

  # Write-only attribute - secrets never stored in state!
  data_json_wo = jsonencode({
    host     = "production-db.company.com"
    port     = "5432" # Store as string to avoid type conversion issues
    database = "myapp"
    username = "app_user"
    password = "super-secret-db-password-123"
    ssl_mode = "require"
  })

  data_json_wo_version = var.secret_version
  delete_all_versions  = true
}

# Store API credentials using write-only attributes
resource "vault_kv_secret_v2" "api_keys" {
  mount = vault_mount.demo.path
  name  = "api/external-services"

  # 🔒 API keys never stored in state
  data_json_wo = jsonencode({
    stripe_secret_key = "sk_live_abcdef123456789"
    sendgrid_api_key  = "SG.super-secret-key-here"
    openai_api_key    = "sk-openai-secret-key-example"
    github_token      = "ghp_github-personal-access-token"
    slack_webhook_url = "https://hooks.slack.com/services/secret/webhook/url"
  })

  data_json_wo_version = var.secret_version
  delete_all_versions  = true
}

# Store application configuration secrets
resource "vault_kv_secret_v2" "app_config" {
  mount = vault_mount.demo.path
  name  = "app/runtime-config"

  # 🔒 Runtime secrets never stored in state
  data_json_wo = jsonencode({
    jwt_signing_key     = "jwt-super-secret-signing-key-2024"
    encryption_key      = "aes-256-encryption-key-super-secure"
    session_secret      = "session-cookie-secret-key"
    oauth_client_secret = "oauth-app-client-secret-secure"
    webhook_secret      = "webhook-validation-secret-key"
  })

  data_json_wo_version = var.secret_version
  delete_all_versions  = true
}

# =====================================================
# PART 2: RETRIEVING SECRETS (Ephemeral Resources Demo)
# =====================================================

# Retrieve database config without storing in state
ephemeral "vault_kv_secret_v2" "db_config" {
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.database_config.name

  # Defer until mount is created
  mount_id = vault_mount.demo.id
}

# Retrieve API keys without storing in state
ephemeral "vault_kv_secret_v2" "api_credentials" {
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.api_keys.name

  mount_id = vault_mount.demo.id
}

# Retrieve app config without storing in state
ephemeral "vault_kv_secret_v2" "app_secrets" {
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.app_config.name

  mount_id = vault_mount.demo.id
}

# ========================================================
# PART 3: USING SECRETS IN OTHER RESOURCES (Secure Demo)
# ========================================================

# Example: Store a complete application configuration
# that combines multiple secrets without exposing them in state
resource "vault_kv_secret_v2" "complete_app_config" {
  mount = vault_mount.demo.path
  name  = "app/final-config"

  # 🔒 Complete config with all secrets - never stored in state
  data_json_wo = jsonencode({
    # Database connection string using retrieved secrets
    database_url = format(
      "postgresql://%s:%s@%s:%s/%s?sslmode=%s",
      ephemeral.vault_kv_secret_v2.db_config.data.username,
      ephemeral.vault_kv_secret_v2.db_config.data.password,
      ephemeral.vault_kv_secret_v2.db_config.data.host,
      ephemeral.vault_kv_secret_v2.db_config.data.port,
      ephemeral.vault_kv_secret_v2.db_config.data.database,
      ephemeral.vault_kv_secret_v2.db_config.data.ssl_mode
    )

    # External API configurations
    stripe_config = {
      secret_key       = tostring(ephemeral.vault_kv_secret_v2.api_credentials.data.stripe_secret_key)
      webhook_endpoint = "/webhooks/stripe"
    }

    sendgrid_config = {
      api_key    = tostring(ephemeral.vault_kv_secret_v2.api_credentials.data.sendgrid_api_key)
      from_email = "noreply@company.com"
    }

    # Application runtime secrets
    security = {
      jwt_key        = tostring(ephemeral.vault_kv_secret_v2.app_secrets.data.jwt_signing_key)
      encryption_key = tostring(ephemeral.vault_kv_secret_v2.app_secrets.data.encryption_key)
      session_secret = tostring(ephemeral.vault_kv_secret_v2.app_secrets.data.session_secret)
    }

    # OAuth configuration
    oauth = {
      client_secret = tostring(ephemeral.vault_kv_secret_v2.app_secrets.data.oauth_client_secret)
      callback_url  = "https://app.company.com/auth/callback"
    }

    # Metadata
    config_version = var.secret_version
    environment    = "production"
    updated_at     = timestamp()
  })

  data_json_wo_version = var.secret_version
  delete_all_versions  = true
}

# Example: Database secrets engine setup using retrieved credentials
# Enable database secrets engine
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Dynamic database credentials"
}

# Configure database connection using ephemeral secrets
resource "vault_database_secret_backend_connection" "postgres" {
  backend = vault_mount.database.path
  name    = "postgres-connection"

  allowed_roles     = ["app-role", "readonly-role"]
  verify_connection = true # Enable verification with real PostgreSQL database

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@localhost:5432/postgres"

    # 🔒 Root password never stored in state
    # Note: Only password_wo supports ephemeral values, username must be static
    username            = "postgres" # Static username
    password_wo         = tostring(ephemeral.vault_kv_secret_v2.db_config.data.password)
    password_wo_version = var.secret_version

    max_open_connections    = 4
    max_connection_lifetime = 3600
  }
}

# Create database role for dynamic credentials
resource "vault_database_secret_backend_role" "app_role" {
  backend = vault_mount.database.path
  name    = "app-role"
  db_name = vault_database_secret_backend_connection.postgres.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]

  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours
}

# ========================================================
# DYNAMIC DATABASE SECRETS DEMO (Requires Real Database)
# ========================================================

# Generate dynamic database credentials (ephemeral)
# Now with real PostgreSQL database connection!
ephemeral "vault_database_secret" "dynamic_db_creds" {
  mount = vault_mount.database.path
  name  = vault_database_secret_backend_role.app_role.name

  # Defer until database role is created
  mount_id = vault_mount.database.id
}

# Example: Using real dynamic database credentials
# This demonstrates actual dynamic credentials from PostgreSQL
resource "vault_kv_secret_v2" "app_with_dynamic_db" {
  mount = vault_mount.demo.path
  name  = "app/dynamic-db-real"

  # 🔒 Real dynamic database credentials from PostgreSQL
  data_json_wo = jsonencode({
    app_name = "myapp-with-dynamic-db"

    # Real dynamic database connection using ephemeral credentials:
    database = {
      host     = "localhost"
      port     = "5432"
      database = "postgres"
      # These are real dynamic, short-lived credentials from Vault!
      username = tostring(ephemeral.vault_database_secret.dynamic_db_creds.username)
      password = tostring(ephemeral.vault_database_secret.dynamic_db_creds.password)
    }

    # Complete connection string using dynamic credentials
    connection_url = format(
      "postgresql://%s:%s@localhost:5432/postgres",
      ephemeral.vault_database_secret.dynamic_db_creds.username,
      ephemeral.vault_database_secret.dynamic_db_creds.password
    )

    # Application metadata
    deployment_time = timestamp()
    security_level  = "maximum"
    credential_type = "vault-dynamic"
    notes           = "Real PostgreSQL users created by Vault that auto-expire after 1 hour"
  })

  data_json_wo_version = var.secret_version
  delete_all_versions  = true
}

# ====================
# OUTPUTS & VERIFICATION
# ====================

# Safe outputs - no sensitive data
output "vault_paths" {
  description = "Paths where secrets are stored in Vault"
  value = {
    mount_path      = vault_mount.demo.path
    database_config = vault_kv_secret_v2.database_config.path
    api_keys        = vault_kv_secret_v2.api_keys.path
    app_config      = vault_kv_secret_v2.app_config.path
    complete_config = vault_kv_secret_v2.complete_app_config.path
    dynamic_db_real = vault_kv_secret_v2.app_with_dynamic_db.path
  }
}

output "database_engine" {
  description = "Database secrets engine information"
  value = {
    mount_path = vault_mount.database.path
    connection = vault_database_secret_backend_connection.postgres.name
    role_name  = vault_database_secret_backend_role.app_role.name
  }
}

output "security_verification" {
  description = "Verification that no secrets are in state"
  value       = "✅ All write-only attributes should show 'null' in terraform.tfstate"
}

# ====================
# DEMO INSTRUCTIONS
# ====================

# To run this demo:
#
# 1. Start Vault dev server:
#    ./scripts/start-vault-dev.sh
#
# 2. Set environment variables:
#    export TF_VAR_vault_token="root"
#    export TF_VAR_vault_address="http://localhost:8200"
#
# 3. Initialize and apply:
#    terraform init
#    terraform plan  # Notice write-only attributes show as "(write-only attribute)"
#    terraform apply
#
# 4. Verify secrets are NOT in state:
#    cat terraform.tfstate | grep -A3 -B1 '"data_json_wo":'
#    # Should show: "data_json_wo": null,
#
# 5. Verify secrets ARE in Vault:
#    vault kv get -field=password demo-secrets/database/postgres
#    vault kv get -field=stripe_secret_key demo-secrets/api/external-services
#
# 6. Test dynamic database credentials:
#    vault read database/creds/app-role
#
# 7. Update secrets by changing version:
#    terraform apply -var="secret_version=2"
#    # Only version number changes in plan, not secret values
#
# 8. Verify ephemeral resources don't appear in state:
#    terraform state list | grep ephemeral
#    # Should return empty - ephemeral resources aren't stored

# Expected terraform plan output:
# + resource "vault_kv_secret_v2" "database_config" {
#     + data_json_wo         = (write-only attribute)  <- Never shows actual secrets
#     + data_json_wo_version = 1
#     + delete_all_versions  = true
#     + id                   = (known after apply)
#     + mount                = "demo-secrets"
#     + name                 = "database/postgres"
#     + path                 = (known after apply)
#   } 
