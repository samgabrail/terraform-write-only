# Terraform 1.11 Game Changer: Write-Only Secrets That Never Touch Your State File

*Finally, truly secure secrets management in Terraform without the state file security nightmare*

## The Problem We've All Been Facing

If you've been using Terraform for any length of time, you've probably lost sleep over this question: **"How do I manage secrets securely without storing them in plain text in my state file?"**

For years, Terraform practitioners have been caught in a security dilemma:
- Store secrets in Terraform state → Security risk 
- Don't use Terraform for secrets → Infrastructure as Code gaps
- Use external secret management → Complex workflows and drift

Today, that changes. **Terraform 1.11 introduces write-only attributes and ephemeral resources**, fundamentally transforming how we handle secrets in Infrastructure as Code. This guide demonstrates the features using **Terraform v1.12.1** and **Vault v1.18.4**.

## What Are Write-Only Attributes?

Write-only attributes are a revolutionary new feature that allows you to:
- ✅ Pass secret values to Terraform resources
- ✅ Use them in your infrastructure provisioning
- ✅ **Never store them in plan or state files**
- ✅ Accept ephemeral values that don't need to be consistent between plan and apply

Think of them as "write-only memory" for Terraform - you can write to them, but they're never persisted or read back.

## Complete Demo: Secure Vault Secrets with Real PostgreSQL

Let's see this in action with a comprehensive example that demonstrates both storing and retrieving secrets, plus real dynamic database secrets. I've created a complete demo that you can run locally with Docker and includes a real PostgreSQL database for testing dynamic credentials.

First, let's look at storing secrets using write-only attributes:

```hcl
# Store database credentials using write-only attributes
# 🔒 These secrets will NEVER appear in terraform.tfstate
resource "vault_kv_secret_v2" "database_config" {
  mount = vault_mount.demo.path
  name  = "database/postgres"
  
  # Write-only attribute - secrets never stored in state!
  data_json_wo = jsonencode({
    host     = "production-db.company.com"
    port     = 5432
    database = "myapp"
    username = "app_user"
    password = "super-secret-db-password-123"
    ssl_mode = "require"
  })
  
  data_json_wo_version = var.secret_version
  delete_all_versions  = true
}
```

When you run `terraform plan`, you'll see:

```
# vault_kv_secret_v2.database_config will be created
+ resource "vault_kv_secret_v2" "database_config" {
    + data_json_wo         = (write-only attribute)  # 🔒 Never shown!
    + data_json_wo_version = 1
    + delete_all_versions  = true
    + id                   = (known after apply)
    + mount                = "demo-secrets"
    + name                 = "database/postgres"
  }
```

## Retrieving Secrets: Ephemeral Resources in Action

Now let's see how to retrieve those secrets without storing them in state using ephemeral resources:

```hcl
# Retrieve database config without storing in state
ephemeral "vault_kv_secret_v2" "db_config" {
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.database_config.name
  
  # Defer until mount is created
  mount_id = vault_mount.demo.id
}

# Use retrieved secrets in other resources
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
    
    # Configuration metadata
    config_version = var.secret_version
    environment = "production"
  })
  
  data_json_wo_version = var.secret_version
}
```

The beauty of this approach is that secrets flow from Vault through ephemeral resources into write-only attributes without ever touching your state file.

## Dynamic Database Secrets: The Ultimate Demo

But wait, there's more! Let's take this to the next level with **real dynamic database secrets**. The demo includes a PostgreSQL database running in Docker to showcase Vault's database secrets engine with auto-expiring credentials.

### Setting Up Dynamic Database Secrets

```hcl
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
  verify_connection = true # With real PostgreSQL database!

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@localhost:5432/postgres"

    # 🔒 Root password never stored in state
    username            = "postgres"
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
```

### Using Dynamic Credentials with Ephemeral Resources

```hcl
# Generate dynamic database credentials (ephemeral)
ephemeral "vault_database_secret" "dynamic_db_creds" {
  mount = vault_mount.database.path
  name  = vault_database_secret_backend_role.app_role.name

  # Defer until database role is created
  mount_id = vault_mount.database.id
}

# Store application config using real dynamic credentials
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
```

### Testing Dynamic Credentials

When you run the complete demo, you can actually test the dynamic credentials:

```bash
# Generate dynamic PostgreSQL credentials
vault read database/creds/app-role
# Output:
# Key                Value
# ---                -----
# lease_id           database/creds/app-role/ybbtk7vwL5jeQB7QIAGqkdP8
# lease_duration     1h
# lease_renewable    true
# password           ORC71M1C-mZjT1ewqkYt
# username           v-token-app-role-PbzYtG6qwATCcteSSX6j-1750864908

# Test the actual database connection
docker exec -it terraform-demo-postgres psql \
  -U v-token-app-role-PbzYtG6qwATCcteSSX6j-1750864908 \
  -d postgres \
  -c "SELECT current_user, now(), 'Dynamic credentials work' as message;"
```

The result? **Real PostgreSQL users created by Vault that automatically expire after 1 hour!**

### Complete Demo Setup

The full demo now includes:

```bash
# 1. Start PostgreSQL database (requires Docker)
./scripts/start-postgres-dev.sh

# 2. Start Vault dev server
./scripts/start-vault-dev.sh

# 3. Set up environment and run demo
source scripts/setup-env.sh && cd examples/

# 4. Run the complete demo
terraform init && terraform apply

# 5. Test dynamic database credentials
vault read database/creds/app-role

# 6. Cleanup when done
cd .. && ./scripts/stop-vault-dev.sh && ./scripts/stop-postgres-dev.sh
```

This demonstrates the complete security model:
- **Static secrets** (API keys, passwords) stored with write-only attributes
- **Dynamic secrets** (database users) generated on-demand with auto-expiration
- **Secret composition** combining ephemeral resources into new configurations
- **Zero state exposure** - no secrets ever stored in Terraform state

## How Updates Work

Since write-only attributes aren't stored in state, updates work differently:

```hcl
resource "vault_kv_secret_v2" "db_root" {
  mount = vault_mount.kvv2.path
  name  = "postgres-root"
  
  # Update the secret
  data_json_wo = jsonencode({
    password = "new-super-secret-password"  # ✅ Updated value
  })
  
  # Increment version to trigger update
  data_json_wo_version = 2  # ✅ Version changed from 1 to 2
}
```

The plan will show:

```
# vault_kv_secret_v2.db_root will be updated in-place
~ resource "vault_kv_secret_v2" "db_root" {
    ~ data_json_wo_version = 1 -> 2
      # Secret value change not shown in plan! 🔒
  }
```

## Current Support and Limitations

### Available Now in Vault Provider 5.0+

The HashiCorp Vault provider leads the way with these write-only attributes:

- `vault_kv_secret_v2.data_json_wo` - KV secrets data
- `vault_database_secret_backend_connection.password_wo` - Database passwords  
- `vault_gcp_secret_backend.credentials_wo` - GCP service account credentials

### Requirements

- **Terraform 1.11+** for write-only attributes *(tested with v1.12.1)*
- **Terraform 1.10+** for ephemeral resources
- **Vault 1.15+** for full compatibility *(tested with v1.18.4)*
- **Updated provider versions** that support the feature

### Current Limitations

- Cannot be used with `set` attributes or nested blocks
- Must be marked as `Required` or `Optional` (not `Computed`)
- Cannot use with `ForceNew` or `Default` values
- No support for aggregate types (maps, lists, sets) directly

## Best Practices for Production

### 1. Use Version Tracking
Always pair write-only attributes with version tracking:

```hcl
data_json_wo_version = var.secret_version
```

### 2. Implement Proper Access Controls
```hcl
# Restrict who can modify secret versions
variable "secret_version" {
  description = "Version of the secret data"
  type        = number
  validation {
    condition     = var.secret_version > 0
    error_message = "Secret version must be positive."
  }
}
```

### 3. Combine with External Secret Management
```hcl
# Read from external secret manager
data "external" "secret" {
  program = ["vault", "kv", "get", "-format=json", "secret/myapp"]
}

resource "vault_kv_secret_v2" "app_secret" {
  mount                = vault_mount.demo.path
  name                 = "application-secrets"
  data_json_wo         = data.external.secret.result.data
  data_json_wo_version = var.secret_version
}
```

## The Security Impact

This isn't just a convenience feature - it's a **fundamental security improvement**:

### Before (Terraform ≤ 1.10)
```bash
# 😱 Secrets visible in state file
cat terraform.tfstate | grep -i password
"password": "super-secret-password"
```

### After (Terraform 1.11+)
```bash
# 🔒 Secrets never stored
cat terraform.tfstate | grep -i password
"password_wo": null
```

## Migration Strategy

### Phase 1: Audit Current Secret Usage
```bash
# Find all sensitive attributes in your state
terraform state list | xargs -I {} terraform state show {} | grep -i "password\|secret\|key"
```

### Phase 2: Gradual Migration
```hcl
# Keep existing attribute during transition
resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.kvv2.path
  name  = "migration-test"
  
  # Old way (deprecated)
  data_json = jsonencode(var.secrets)
  
  # New way (preferred)
  data_json_wo         = jsonencode(var.secrets)
  data_json_wo_version = var.secret_version
}
```

### Phase 3: Complete Migration
Remove old attributes and update workflows to use version-based updates.

## What This Means for the Future

This feature opens up possibilities that were previously impossible or impractical:

1. **True GitOps for Secrets** - Store Terraform configs in Git without security concerns
2. **Simplified Compliance** - No secrets in state files = easier audits
3. **Better CI/CD Integration** - Secrets can flow through pipelines without persistence
4. **Reduced Attack Surface** - Fewer places where secrets can be exposed

## Getting Started Today

### 1. Clone the Demo Repository and Setup
```bash
# Clone the demo (or download the files)
git clone <your-demo-repo>
cd terraform-write-only

# Start PostgreSQL database (requires Docker)
./scripts/start-postgres-dev.sh

# Start the Vault development server
./scripts/start-vault-dev.sh

# Set up environment variables
source scripts/setup-env.sh
```

### 2. Run the Complete Demo
```bash
# Navigate to the demo
cd examples/

# Initialize Terraform
terraform init

# See the plan (notice write-only attributes)
terraform plan

# Apply the configuration
terraform apply
```

### 3. Verify Security and Test Dynamic Credentials
```bash
# Check that secrets aren't in state
cat terraform.tfstate | grep -A 3 -B 1 '"data_json_wo":'
# Should show: "data_json_wo": null,

# But verify secrets ARE in Vault
vault kv get -field=password demo-secrets/database/postgres
vault kv get demo-secrets/api/external-services

# Test dynamic database credentials
vault read database/creds/app-role
# Generates real PostgreSQL user with 1-hour TTL!

# Check ephemeral resources don't appear in state
terraform state list | grep ephemeral
# Should return empty - ephemeral resources aren't stored
```

## Looking Ahead

This is just the beginning. Expect to see:
- More providers adopting write-only attributes
- Enhanced tooling for secret version management
- Better integration with external secret management systems
- Expanded support for complex data types

The combination of write-only attributes and ephemeral resources represents the most significant advancement in Terraform security since the introduction of sensitive variables. It's not just about adding a new feature - it's about fundamentally changing how we think about secrets in Infrastructure as Code.

## Conclusion

Terraform 1.11's write-only attributes solve one of the biggest pain points in Infrastructure as Code: secure secrets management. By never storing secrets in plan or state files, we can finally have our cake and eat it too - full IaC coverage with enterprise-grade security.

The future of Terraform is more secure, and it starts with upgrading to 1.11 and embracing write-only attributes. Your security team (and your future self) will thank you.

---

*Want to learn more? Check out the [official documentation](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/write-only-arguments) and the [Vault provider guide](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/guides/using_write_only_attributes) for write-only attributes.*

**Ready to get started?** Upgrade to Terraform 1.11 today and experience the future of secure Infrastructure as Code. 