# ========================================================
# INSECURE DEMO: Traditional Terraform Secrets (DANGEROUS!)
# ========================================================
# 
# ⚠️  WARNING: This demo shows the OLD, INSECURE way of handling secrets
# ⚠️  DO NOT use this approach in production!
# ⚠️  This is for educational purposes only to demonstrate the security problem
#
# This file demonstrates what happens when you DON'T use write-only attributes:
# - Secrets appear in terraform plan output
# - Secrets are stored in terraform.tfstate file
# - Anyone with access to state can see all secrets
# - Security nightmare for production environments
#
# After running this demo, we'll show the SECURE approach with write-only attributes
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
  sensitive   = true # This doesn't help - secrets still end up in state!
}

# ========================================================
# PART 1: INSECURE STATIC SECRET STORAGE (Traditional Approach)
# ========================================================

# Create KV mount for our insecure demo
resource "vault_mount" "insecure_demo" {
  path        = "insecure-secrets"
  type        = "kv"
  options     = { version = "2" }
  description = "INSECURE demo mount - secrets will be exposed in state!"
}

# ⚠️  DANGEROUS: Store database credentials using regular data_json attribute
# This will expose ALL secrets in the terraform plan and state file!
resource "vault_kv_secret_v2" "insecure_database_config" {
  mount               = vault_mount.insecure_demo.path
  name                = "database/postgres"
  delete_all_versions = true

  # 💀 SECURITY NIGHTMARE: Using regular data_json attribute
  # These secrets will be VISIBLE in:
  # 1. terraform plan output
  # 2. terraform.tfstate file  
  # 3. Any logs or CI/CD outputs
  data_json = jsonencode({
    host     = "production-db.company.com"
    port     = "5432"
    database = "myapp"
    username = "app_user"
    password = "super-secret-db-password-123" # 💀 EXPOSED!
    ssl_mode = "require"
  })
}

# ========================================================
# PART 2: INSECURE DYNAMIC DATABASE SECRETS (Traditional Approach)  
# ========================================================

# Enable database secrets engine
resource "vault_mount" "insecure_database" {
  path        = "insecure-database"
  type        = "database"
  description = "INSECURE database secrets - password will be exposed in state!"
}

# ⚠️  DANGEROUS: Configure database connection using regular password attribute
# This will expose the root database password in the state file!
resource "vault_database_secret_backend_connection" "insecure_postgres" {
  backend = vault_mount.insecure_database.path
  name    = "postgres-connection"

  allowed_roles     = ["insecure-app-role"]
  verify_connection = true

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@localhost:5432/postgres"

    # 💀 SECURITY NIGHTMARE: Using regular password attribute
    # This root password will be VISIBLE in terraform.tfstate!
    username = "postgres"
    password = "super-secret-db-password-123" # 💀 EXPOSED IN STATE!
  }
}

# Create database role for generating dynamic credentials
resource "vault_database_secret_backend_role" "insecure_app_role" {
  backend = vault_mount.insecure_database.path
  name    = "insecure-app-role"
  db_name = vault_database_secret_backend_connection.insecure_postgres.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]

  default_ttl = 3600 # 1 hour
  max_ttl     = 3600
}

# ⚠️  DANGEROUS: Read secrets using regular data sources
# This will also expose secrets in state!
data "vault_kv_secret_v2" "insecure_read_db_config" {
  mount = vault_mount.insecure_demo.path
  name  = vault_kv_secret_v2.insecure_database_config.name
}

# ⚠️  DANGEROUS: Create composite configuration using exposed secrets
resource "vault_kv_secret_v2" "insecure_complete_config" {
  mount               = vault_mount.insecure_demo.path
  name                = "app/complete-insecure-config"
  delete_all_versions = true

  # 💀 COMBINING SECRETS MAKES IT WORSE - MORE EXPOSURE!
  data_json = jsonencode({
    # All these secrets will be visible in state file
    application_name = "myapp-production"

    # Database configuration using retrieved secrets (ALL EXPOSED!)
    database_url = format(
      "postgresql://%s:%s@%s:%s/%s?sslmode=%s",
      data.vault_kv_secret_v2.insecure_read_db_config.data["username"], # 💀 EXPOSED!
      data.vault_kv_secret_v2.insecure_read_db_config.data["password"], # 💀 EXPOSED!
      data.vault_kv_secret_v2.insecure_read_db_config.data["host"],     # 💀 EXPOSED!
      data.vault_kv_secret_v2.insecure_read_db_config.data["port"],     # 💀 EXPOSED!
      data.vault_kv_secret_v2.insecure_read_db_config.data["database"], # 💀 EXPOSED!
      data.vault_kv_secret_v2.insecure_read_db_config.data["ssl_mode"]  # 💀 EXPOSED!
    )

    # Metadata
    created_at     = timestamp()
    security_level = "NONE - ALL SECRETS EXPOSED!" # 💀 TRUTH!
    warning        = "DO NOT USE THIS APPROACH IN PRODUCTION!"
  })
}

# ========================================================
# OUTPUTS SHOWING THE SECURITY PROBLEM
# ========================================================

# Even with sensitive = true, the data is still in the state file!
output "insecure_warning" {
  description = "Warning about security exposure"
  value = {
    warning = "🚨 ALL SECRETS ARE EXPOSED IN terraform.tfstate FILE!"
    impact  = "Anyone with access to state can see production secrets"
    risk    = "CRITICAL - Never use this approach in production"
  }
}

output "insecure_vault_paths" {
  description = "Paths where insecure secrets are stored"
  value = {
    kv_mount_path       = vault_mount.insecure_demo.path
    database_mount_path = vault_mount.insecure_database.path
    static_secret_path  = vault_kv_secret_v2.insecure_database_config.path
    dynamic_creds_path  = "${vault_mount.insecure_database.path}/creds/${vault_database_secret_backend_role.insecure_app_role.name}"
  }
}

# This output will show sensitive data even with sensitive = true
output "exposed_secrets_demo" {
  description = "Example of how secrets get exposed (for educational purposes only)"
  sensitive   = true # This doesn't prevent state file exposure!
  value = {
    database_password = data.vault_kv_secret_v2.insecure_read_db_config.data["password"]
    root_db_password  = vault_database_secret_backend_connection.insecure_postgres.postgresql[0].password
    warning           = "These secrets are in your state file even with sensitive = true!"
  }
}

# ====================
# SECURITY DEMONSTRATION COMMANDS
# ====================

# After applying this configuration, run these commands to see the security problem:
#
# 1. Check terraform plan output:
#    terraform plan
#    # You'll see ALL secret values in plain text!
#
# 2. Check terraform state file:
#    cat terraform.tfstate | jq '.resources[] | select(.type=="vault_kv_secret_v2") | .instances[0].attributes.data_json'
#    # You'll see ALL secrets in plain text in the state file!
#
# 3. Search for specific secrets:
#    grep -r "super-secret-db-password-123" terraform.tfstate
#    grep -r "super-secret-db-password-123" terraform.tfstate
#    # All will return matches - secrets are exposed!
#
# 4. Check database connection password exposure:
#    terraform state show vault_database_secret_backend_connection.insecure_postgres
#    # You'll see the root database password in plain text!
#
# 5. Test dynamic credentials (they work, but root password is exposed):
#    vault read insecure-database/creds/insecure-app-role
#    # Dynamic credentials work, but the root password is in your state file!
#
# This demonstrates why write-only attributes are revolutionary for security!

# ====================
# WHAT STUDENTS WILL SEE
# ====================

# 1. terraform plan will show:
#    + data_json = jsonencode({
#        + password = "super-secret-db-password-123"  # 💀 VISIBLE!
#      })
#    + password = "super-secret-db-password-123"  # 💀 VISIBLE!
#
# 2. terraform.tfstate will contain:
#    "data_json": "{\"password\":\"super-secret-db-password-123\"}"
#    "password": "super-secret-db-password-123"
#
# 3. Anyone with state file access can extract:
#    - Static database passwords
#    - Root database passwords for dynamic secrets
#    - All connection details
#    - Everything needed to access production systems!
#
# This is why write-only attributes are a GAME CHANGER! 🚀 

