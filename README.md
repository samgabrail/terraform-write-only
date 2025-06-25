# Terraform Write-Only Secrets Demo

> **Terraform 1.11 Game Changer**: Store and retrieve secrets in HashiCorp Vault without them ever touching your state file!

This repository demonstrates Terraform's revolutionary **write-only attributes** and **ephemeral resources** features, which finally solve the biggest security problem in Infrastructure as Code: managing secrets without storing them in state files.

## ✅ Prerequisites Met

You already have the required versions:
- ✅ **Terraform v1.12.1** (requires 1.11+)  
- ✅ **Vault v1.18.4** (excellent compatibility)

## 🚀 Quick Start (Complete Demo with PostgreSQL)

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

## 🔒 What This Demo Shows

### Part 1: Write-Only Attributes (Storing Secrets)
```hcl
resource "vault_kv_secret_v2" "database_config" {
  # 🔒 These secrets NEVER appear in terraform.tfstate
  data_json_wo = jsonencode({
    password = "super-secret-db-password-123"
    # ... other secrets
  })
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

### Part 3: Using Secrets Together
```hcl
resource "vault_kv_secret_v2" "complete_app_config" {
  # Combines retrieved secrets into new configurations
  # All using write-only attributes - completely secure!
  data_json_wo = jsonencode({
    database_url = format("postgresql://%s:%s@%s...", 
        ephemeral.vault_kv_secret_v2.db_config.data.username,
  ephemeral.vault_kv_secret_v2.db_config.data.password,
  # ... ephemeral secrets flow securely
    )
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
```

## 📁 Repository Structure

```
terraform-write-only/
├── examples/
│   └── complete-demo.tf          # Complete demo showing all features
├── scripts/
│   ├── start-vault-dev.sh        # Vault dev server setup
│   ├── stop-vault-dev.sh         # Stop Vault server
│   ├── start-postgres-dev.sh     # PostgreSQL database setup
│   ├── stop-postgres-dev.sh      # Stop PostgreSQL database
│   └── setup-env.sh              # Environment variables
├── terraform-write-only-secrets-blog.md      # Comprehensive blog post
├── terraform-write-only-secrets-video-script.md  # Video content
└── README.md                     # This file
```

## 🛠️ Demo Features

The `complete-demo.tf` demonstrates:

- **3 types of secrets**: Database credentials, API keys, application config
- **Write-only storage**: All secrets use `data_json_wo` (never in state)
- **Ephemeral retrieval**: Read secrets without state storage
- **Secret composition**: Combine multiple secrets securely
- **Dynamic credentials**: Real PostgreSQL database secrets with auto-expiration
- **Version tracking**: Update secrets safely with version numbers

## 📚 Additional Resources

- **Blog Post**: `terraform-write-only-secrets-blog.md` - Comprehensive guide
- **Video Script**: `terraform-write-only-secrets-video-script.md` - Video content
- **Official Docs**: 
  - [Write-Only Attributes](https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/write-only-arguments)
  - [Ephemeral Resources](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/ephemeral-resources/kv_secret_v2)
  - [Vault Provider Guide](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/guides/using_write_only_attributes)

## 🔧 Full Cleanup

```bash
# Stop all services
./scripts/stop-vault-dev.sh
./scripts/stop-postgres-dev.sh

# Clean up Terraform resources (optional)
cd examples/ && terraform destroy

# Remove any leftover files (optional)
rm -f vault-dev.log vault-dev.pid

# Remove Docker container (optional)
docker rm terraform-demo-postgres
```

## 🎯 Key Benefits

- ✅ **Zero secrets in state files** - Ever!
- ✅ **GitOps compatible** - State files are safe to store in Git
- ✅ **CI/CD friendly** - Version-based secret updates  
- ✅ **Audit compliant** - No secret exposure in plans or logs
- ✅ **Works with any secret management system** - External data sources supported

## 🔄 Updating Secrets

```bash
# Update secrets by incrementing version
terraform apply -var="secret_version=2"

# Only version changes in plan - secrets never shown!
# ~ data_json_wo_version = 1 -> 2
```

---

**🎉 This is the future of secure Infrastructure as Code!** 

No more secrets in state files, no more security nightmares. Just clean, secure, auditable infrastructure management with Terraform. 