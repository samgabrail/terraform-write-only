# Terraform Write-Only Secrets Demo

> **Terraform 1.11 Game Changer**: Store and retrieve secrets in HashiCorp Vault without them ever touching your state file!

This repository demonstrates Terraform's revolutionary **write-only attributes** and **ephemeral resources** features, which finally solve the biggest security problem in Infrastructure as Code: managing secrets without storing them in state files.

## ✅ Prerequisites Met

You already have the required versions:
- ✅ **Terraform v1.12.1** (requires 1.11+)  
- ✅ **Vault v1.18.4** (excellent compatibility)

> **📁 Important**: All commands below should be run from the project root directory (`terraform-write-only/`)

## 🚀 Quick Start Options

### 🎓 **Educational Demo Sequence (Recommended for Learning)**

**See the security problem FIRST, then the solution:**

```bash
# Run from project root directory: terraform-write-only/

# 1. Start services
./scripts/start-postgres-dev.sh
./scripts/start-vault-dev.sh
source scripts/setup-env.sh

# 2. Run INSECURE demo (shows the problem)
./scripts/demo-insecure-secrets.sh

# 3. Run SECURE demo (shows the solution)
./scripts/demo-secure-secrets.sh
```

**Perfect for students and presentations!** Shows the dramatic before/after comparison with complete state file analysis.

> **📍 Note**: The demo scripts automatically navigate to the correct directories (`examples/insecure/` and `examples/secure/`) and handle all the setup for you.

### ⚡ **Direct Secure Demo (Production Focus)**

**Skip straight to the secure approach:**

```bash
# Run from project root directory: terraform-write-only/

# 1. Start PostgreSQL database (requires Docker)
./scripts/start-postgres-dev.sh

# 2. Start Vault dev server (provides next step guidance)
./scripts/start-vault-dev.sh

# 3. Set up environment and run demo
source scripts/setup-env.sh && cd examples/secure/

# 4. Run the complete demo
terraform init && terraform apply

# 5. Test dynamic database credentials
vault read database/creds/app-role

# 6. Cleanup when done
cd ../../ && ./scripts/stop-vault-dev.sh && ./scripts/stop-postgres-dev.sh
```

### 🔍 **Manual Exploration (Optional)**

**For advanced users who want to explore the configurations manually:**

```bash
# Run from project root directory: terraform-write-only/

# 1. Start services
./scripts/start-postgres-dev.sh
./scripts/start-vault-dev.sh
source scripts/setup-env.sh

# 2. Explore the insecure approach manually
cd examples/insecure/ && terraform init && terraform plan

# 3. Or explore the secure approach manually  
cd ../secure/ && terraform init && terraform plan
```

## 🔒 What This Demo Shows

### Part 1: Write-Only Attributes (Storing Secrets)
```hcl
resource "vault_kv_secret_v2" "database_config" {
  # 🔒 These secrets NEVER appear in terraform.tfstate
  data_json_wo = jsonencode({
    password = "super-secret-db-password-123"
    # ... other secrets
  })
  data_json_wo_version = var.secret_version
}
```

### Part 2: Ephemeral Resources (Retrieving Secrets)
```hcl
ephemeral "vault_kv_secret_v2" "db_config" {
  # Retrieves secrets without storing in state
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.database_config.name
}
```

### Part 3: Dynamic Database Secrets (Real PostgreSQL)
```hcl
resource "vault_database_secret_backend_connection" "postgres" {
  postgresql {
    # 🔒 Root password never stored in state
    password_wo         = "postgres-root-password-123"
    password_wo_version = var.secret_version
  }
}

ephemeral "vault_database_secret" "dynamic_db_creds" {
  # Generate real auto-expiring PostgreSQL users
  mount = vault_mount.database.path
  name  = vault_database_secret_backend_role.app_role.name
}
```

### Part 4: Secret Composition (Advanced Integration)
```hcl
resource "vault_kv_secret_v2" "complete_app_config" {
  # Combines retrieved secrets into new configurations
  data_json_wo = jsonencode({
    database_url = format("postgresql://%s:%s@%s...", 
      ephemeral.vault_kv_secret_v2.db_config.data.username,
      ephemeral.vault_kv_secret_v2.db_config.data.password,
      # ... ephemeral secrets flow securely
    )
    
    # Dynamic credentials from real PostgreSQL
    dynamic_database = {
      username = tostring(ephemeral.vault_database_secret.dynamic_db_creds.username)
      password = tostring(ephemeral.vault_database_secret.dynamic_db_creds.password)
    }
  })
}
```

## 🔍 Verify Security

After running the demo, verify that secrets are **never stored in state**:

```bash
# Check state file - should show null for all write-only attributes
cat terraform.tfstate | grep -A 3 -B 1 '"data_json_wo":'
# Output: "data_json_wo": null,

# But secrets ARE in Vault
vault kv get -field=password demo-secrets/database/postgres
# Output: super-secret-db-password-123

# Ephemeral resources don't appear in state at all
terraform state list | grep ephemeral
# Output: (empty - they're not stored!)

# Test real dynamic database credentials
vault read database/creds/app-role
docker exec terraform-demo-postgres psql -U [dynamic-user] -d postgres -c "SELECT current_user;"
```

## 📁 Repository Structure

```
terraform-write-only/
├── examples/
│   ├── secure/
│   │   └── complete-demo.tf     # ✅ SECURE: Write-only attributes + ephemeral resources
│   └── insecure/
│       └── insecure-demo.tf     # ⚠️  Educational: Shows security problem
├── scripts/                     # Run all scripts from project root
│   ├── demo-insecure-secrets.sh # 📚 Educational: Shows security problem
│   ├── demo-secure-secrets.sh   # 📚 Educational: Shows secure solution
│   ├── setup-env.sh             # Environment variables
│   ├── start-vault-dev.sh       # Vault dev server setup
│   ├── stop-vault-dev.sh        # Stop Vault server
│   ├── start-postgres-dev.sh    # PostgreSQL database setup
│   └── stop-postgres-dev.sh     # Stop PostgreSQL database
├── terraform-write-only-secrets-blog.md      # Comprehensive blog post
├── terraform-write-only-secrets-video-script.md  # Video content
└── README.md                    # This file
```

## 🛠️ Demo Features

### 🎓 **Educational Comparison Demos**

**`examples/insecure/insecure-demo.tf`** (Traditional approach - DANGEROUS):
- **Static secrets**: Database credentials exposed via `data_json`
- **Dynamic secrets**: Root password exposed via `password` attribute
- **Data sources**: Retrieved secrets exposed in state
- **State pollution**: All secrets stored in `terraform.tfstate` file
- **Security nightmare**: Anyone with state access sees everything
- **Educational purpose**: Shows why write-only attributes are needed

**`examples/secure/complete-demo.tf`** (Secure approach - REVOLUTIONARY):
- **Write-only storage**: All secrets using write-only attributes
- **Ephemeral retrieval**: Read secrets without state storage
- **Secret composition**: Combine multiple secrets securely
- **Real PostgreSQL**: Dynamic database credentials with auto-expiration
- **Complete integration**: Full secure workflow demonstration

### 🎬 **Interactive Educational Scripts**

**`./scripts/demo-insecure-secrets.sh`**:
- Shows traditional approach security problems
- Demonstrates state file secret exposure
- Analyzes attack vectors and impact
- Searches state file for exposed credentials
- Educational warnings and explanations

**`./scripts/demo-secure-secrets.sh`**:
- Demonstrates secure write-only attributes
- Shows ephemeral resources in action
- Tests real PostgreSQL dynamic credentials
- Analyzes secure state file (null values)
- Complete security verification

## 📚 Additional Resources

- **Blog Post**: `terraform-write-only-secrets-blog.md` - Comprehensive guide
- **Video Script**: `terraform-write-only-secrets-video-script.md` - Video content
- **Official Docs**: 
  - [Write-Only Attributes](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/write-only-arguments)
  - [Ephemeral Resources](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/ephemeral-resources/kv_secret_v2)
  - [Vault Provider Guide](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/guides/using_write_only_attributes)

## 🔧 Full Cleanup

```bash
# Run from project root directory: terraform-write-only/

# Stop all services
./scripts/stop-vault-dev.sh
./scripts/stop-postgres-dev.sh

# Clean up Terraform resources (run from appropriate directory)
cd examples/secure/ && terraform destroy
# OR
cd examples/insecure/ && terraform destroy

# Remove Docker container (optional)
docker rm terraform-demo-postgres
```

## 🎯 Key Benefits

- ✅ **Zero secrets in state files** - Ever!
- ✅ **GitOps compatible** - State files are safe to store in Git
- ✅ **CI/CD friendly** - Version-based secret updates  
- ✅ **Audit compliant** - No secret exposure in plans or logs
- ✅ **Real database integration** - Dynamic credentials with PostgreSQL
- ✅ **Educational workflow** - Learn the problem, then the solution
- ✅ **Production ready** - Complete security model

## 🔄 Updating Secrets

```bash
# Update secrets by incrementing version
terraform apply -var="secret_version=2"

# Only version changes in plan - secrets never shown!
# ~ data_json_wo_version = 1 -> 2
```

## 🎓 Educational Sequence Benefits

1. **Problem First**: See exactly why traditional approaches are dangerous
2. **Solution Second**: Experience the dramatic security improvement
3. **State Analysis**: Compare before/after state files side-by-side
4. **Real Testing**: Dynamic PostgreSQL credentials with actual database
5. **Complete Verification**: Thorough security analysis and testing

---

**🎉 This is the future of secure Infrastructure as Code!** 

No more secrets in state files, no more security nightmares. Just clean, secure, auditable infrastructure management with Terraform. 