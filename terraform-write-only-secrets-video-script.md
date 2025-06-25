# Terraform Write-Only Secrets Video Script
*Duration: 12-15 minutes*
*Target Audience: DevOps Engineers, Platform Engineers, Security-conscious developers*

---

## Video Title Options:
1. **"Terraform 1.11 GAME CHANGER: Secrets That Never Touch Your State File!"**
2. **"Finally! Secure Secrets in Terraform Without State File Risk"**
3. **"The End of Terraform's Biggest Security Problem (Write-Only Attributes)"**

## Video Description:
Terraform 1.11 introduces write-only attributes - a revolutionary feature that finally solves the biggest security problem in Infrastructure as Code: how to manage secrets without storing them in state files. In this video, I'll show you exactly how to use write-only attributes with HashiCorp Vault (tested with Terraform v1.12.1 and Vault v1.18.4), demonstrate real dynamic database secrets with PostgreSQL, and walk through complete production-ready examples.

🔗 **Links:**
- HashiCorp Write-Only Attributes Docs: https://developer.hashicorp.com/terraform/plugin/sdkv2/resources/write-only-arguments
- Vault Provider Guide: https://registry.terraform.io/providers/hashicorp/vault/latest/docs/guides/using_write_only_attributes
- Sample Code: [GitHub repository link]

⏰ **Timestamps:**
00:00 - The Problem We've All Been Facing
02:30 - What Are Write-Only Attributes?
04:45 - Live Demo: Secure Vault Secrets
07:15 - Ephemeral Resources Integration
09:30 - Dynamic Database Secrets with PostgreSQL
12:00 - Production Best Practices
14:15 - Migration Strategy
15:30 - Wrap-up & Next Steps

---

## SCRIPT

### [00:00 - 02:30] INTRO & PROBLEM STATEMENT

**[ON SCREEN: Terraform logo, state file with visible secrets]**

**HOST:** Hey everyone! If you've been using Terraform for infrastructure as code, you've probably lost sleep over this question: "How do I manage secrets securely without storing them in plain text in my state file?" Today I'm demonstrating the solution using Terraform v1.12.1 and Vault v1.18.4.

**[SCREEN: Split screen showing state file with password visible]**

For years, we've been caught in this impossible security dilemma. Either we store secrets in Terraform state - which is a massive security risk - or we don't use Terraform for secrets management, creating gaps in our Infrastructure as Code approach.

**[SCREEN: Diagram showing the security trilemma]**

**HOST:** Well, that nightmare is officially over. Terraform 1.11 just dropped a game-changing feature called write-only attributes, and when combined with ephemeral resources, it completely transforms how we handle secrets in Infrastructure as Code.

**[SCREEN: Terraform 1.11 release notes highlight]**

I'm going to show you exactly how this works, demonstrate it live with HashiCorp Vault, and give you production-ready examples you can use today.

But first, let me show you just how big this problem really was...

### [02:30 - 04:45] EXPLAINING WRITE-ONLY ATTRIBUTES

**[SCREEN: Terminal showing terraform.tfstate with secrets visible]**

**HOST:** Here's what happened before Terraform 1.11. Even with sensitive = true, your secrets still end up in the state file. Anyone with access to your state file - and that's usually a lot of people - can see your production database passwords, API keys, everything.

**[SCREEN: Animation showing write-only concept]**

Write-only attributes change everything. Think of them as "write-only memory" for Terraform. You can pass secret values to resources, use them for infrastructure provisioning, but they are NEVER stored in plan files or state files.

**[SCREEN: Code comparison - before/after]**

Here's what makes them special:
- They accept both regular and ephemeral values
- Values are only available during configuration
- State values are ALWAYS null for write-only attributes
- They work perfectly with secret rotation and CI/CD pipelines

**[SCREEN: Feature comparison table]**

The best part? The Terraform SDKv2 automatically nullifies these values before sending any response back to Terraform. Providers don't even need to handle this - it's built into the framework.

### [04:45 - 07:15] LIVE DEMO: COMPLETE VAULT SECRETS WORKFLOW

**[SCREEN: Terminal with project directory]**

**HOST:** Alright, let's see this in action with a complete demo. I've created a comprehensive example that shows storing secrets in Vault, retrieving them, AND real dynamic database secrets with PostgreSQL - all without any secrets touching the state file.

**[TYPING IN TERMINAL]**
```bash
# Let's start by setting up our PostgreSQL database
./scripts/start-postgres-dev.sh
```

**[SCREEN: Docker pulling PostgreSQL image and starting container]**

**HOST:** I'm using Docker to spin up a real PostgreSQL database for this demo. This lets us test actual dynamic database credentials, not just mock examples.

**[TYPING IN TERMINAL]**
```bash
# Now let's start our Vault dev server
./scripts/start-vault-dev.sh
```

**HOST:** I've created a handy script that starts a Vault development server for us. This sets up everything we need for the demo.

**[SCREEN: Script output showing Vault starting]**

Now let's set up our environment and look at our demo configuration:

**[TYPING]**
```bash
source scripts/setup-env.sh
cd examples/
```

**[SCREEN: VS Code showing complete-demo.tf]**

**HOST:** Here's our comprehensive demo. It has three main parts - storing secrets, retrieving secrets, and using secrets in other resources. Let me show you the storing part first:

**[HIGHLIGHTING CODE]**
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
}
```

**HOST:** Notice the `data_json_wo` attribute - that's our write-only attribute. Now let's see the plan:

**[SCREEN: Terminal running terraform init && terraform plan]**

```bash
terraform init
terraform plan
```

**[SCREEN: Plan output]**
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

**HOST:** See that? It says "write-only attribute" instead of showing the actual secret value. This applies to ALL our secrets - database credentials, API keys, everything. Now let's apply this:

**[SCREEN: Terminal running terraform apply]**

**HOST:** Perfect! Now here's the crucial test - let's check the state file to see what happened to our secrets:

**[SCREEN: Terminal showing state inspection]**

```bash
cat terraform.tfstate | grep -A 3 -B 1 '"data_json_wo":'
```

**[SCREEN: State file output]**
```json
"data_json_wo": null,
"data_json_wo_version": 1,
```

**HOST:** Look at that! Every single write-only attribute is null in the state file. Our production secrets never touched the state file, but Vault received them and stored them securely.

Let's verify they're actually in Vault:

**[SCREEN: Terminal]**
```bash
vault kv get -field=password demo-secrets/database/postgres
# Returns: super-secret-db-password-123
```

### [07:15 - 09:30] EPHEMERAL RESOURCES: RETRIEVING SECRETS

**[SCREEN: Scrolling to ephemeral resources section]**

**HOST:** Now here's where it gets really powerful. Our demo also shows how to retrieve secrets using ephemeral resources. Look at this:

**[HIGHLIGHTING CODE]**
```hcl
# Retrieve database config without storing in state
ephemeral "vault_kv_secret_v2" "db_config" {
  mount = vault_mount.demo.path
  name  = vault_kv_secret_v2.database_config.name
  
  # Defer until mount is created
  mount_id = vault_mount.demo.id
}
```

**HOST:** This ephemeral resource reads our secrets from Vault but never stores them in state. Now watch how we use those retrieved secrets in other resources:

**[HIGHLIGHTING CODE]**
```hcl
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
  })
}
```

**HOST:** This is incredible - secrets flow from Vault through ephemeral resources into write-only attributes without EVER touching the state file. Let me verify this:

**[SCREEN: Terminal commands]**
```bash
# Check ephemeral resources don't appear in state
terraform state list | grep ephemeral
# Should return empty - ephemeral resources aren't stored!

# Verify secrets are accessible
vault kv get demo-secrets/api/external-services
```

**HOST:** Perfect! The ephemeral resources aren't stored in state, but we can access the secrets in Vault. Now let me show you how updates work with version tracking:

**[SCREEN: Terminal]**
```bash
# Update secrets by incrementing version
terraform apply -var="secret_version=2"
```

**[SCREEN: Plan output]**
```
# vault_kv_secret_v2.database_config will be updated in-place
~ resource "vault_kv_secret_v2" "database_config" {
    ~ data_json_wo_version = 1 -> 2
      # Secret value change not shown in plan!
  }
```

**HOST:** See that? Only the version number changes in the plan - the actual secret values are never shown, even during updates!

### [09:30 - 12:00] DYNAMIC DATABASE SECRETS: THE ULTIMATE DEMO

**[SCREEN: Scrolling to database secrets engine section]**

**HOST:** Now let me show you something really powerful - dynamic database secrets with a real PostgreSQL database. This takes write-only attributes to the next level by combining them with Vault's database secrets engine.

**[HIGHLIGHTING CODE]**
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
  verify_connection = true # With our real PostgreSQL database!

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@localhost:5432/postgres"

    # 🔒 Root password never stored in state
    username            = "postgres"
    password_wo         = tostring(ephemeral.vault_kv_secret_v2.db_config.data.password)
    password_wo_version = var.secret_version
  }
}
```

**HOST:** Notice how we're using `password_wo` - another write-only attribute - to pass the database root password without storing it in state. And we're getting that password from our ephemeral resource!

**[HIGHLIGHTING CODE]**
```hcl
# Generate dynamic database credentials (ephemeral)
ephemeral "vault_database_secret" "dynamic_db_creds" {
  mount = vault_mount.database.path
  name  = vault_database_secret_backend_role.app_role.name

  # Defer until database role is created
  mount_id = vault_mount.database.id
}
```

**HOST:** This ephemeral resource will generate fresh PostgreSQL credentials every time we run Terraform. Let's test this:

**[SCREEN: Terminal running terraform apply]**

**HOST:** Now let's see Vault generate dynamic database credentials:

**[TYPING IN TERMINAL]**
```bash
vault read database/creds/app-role
```

**[SCREEN: Vault output]**
```
Key                Value
---                -----
lease_id           database/creds/app-role/ybbtk7vwL5jeQB7QIAGqkdP8
lease_duration     1h
lease_renewable    true
password           ORC71M1C-mZjT1ewqkYt
username           v-token-app-role-PbzYtG6qwATCcteSSX6j-1750864908
```

**HOST:** Look at that! Vault just created a real PostgreSQL user with a 1-hour TTL. Let's test if it actually works:

**[TYPING IN TERMINAL]**
```bash
docker exec -it terraform-demo-postgres psql \
  -U v-token-app-role-PbzYtG6qwATCcteSSX6j-1750864908 \
  -d postgres \
  -c "SELECT current_user, now(), 'Dynamic credentials work' as message;"
```

**[SCREEN: PostgreSQL query result]**
```
                   current_user                   |              now              |         message          
--------------------------------------------------+-------------------------------+--------------------------
 v-token-app-role-PbzYtG6qwATCcteSSX6j-1750864908 | 2025-06-25 15:22:10.688907+00 | Dynamic credentials work
```

**HOST:** INCREDIBLE! We just connected to PostgreSQL using a dynamically generated user that will automatically expire in 1 hour. And here's the best part - let's see how we use these dynamic credentials in our Terraform configuration:

**[HIGHLIGHTING CODE]**
```hcl
# Store application config using real dynamic credentials
resource "vault_kv_secret_v2" "app_with_dynamic_db" {
  mount = vault_mount.demo.path
  name  = "app/dynamic-db-real"

  # 🔒 Real dynamic database credentials from PostgreSQL
  data_json_wo = jsonencode({
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
  })
}
```

**HOST:** This is the complete security model in action:
- Static secrets stored with write-only attributes
- Dynamic secrets generated on-demand with auto-expiration
- Secret composition combining ephemeral resources into new configurations
- Zero state exposure - no secrets ever stored in Terraform state

**[SCREEN: Checking the final secret in Vault]**
```bash
vault kv get demo-secrets/app/dynamic-db-real
```

**HOST:** And there it is - our complete application configuration with real dynamic PostgreSQL credentials, all stored securely in Vault but never touching our Terraform state file!

### [12:00 - 14:15] PRODUCTION BEST PRACTICES

**[SCREEN: Best practices slide]**

**HOST:** Now let's talk about production best practices, because this is where the rubber meets the road.

**First: Always use version tracking with variables:**

**[TYPING]**
```hcl
variable "secret_version" {
  description = "Version of the secret data"
  type        = number
  validation {
    condition     = var.secret_version > 0
    error_message = "Secret version must be positive."
  }
}

resource "vault_kv_secret_v2" "production_secret" {
  mount                = vault_mount.secrets.path
  name                 = "app-credentials"
  data_json_wo         = var.secret_data
  data_json_wo_version = var.secret_version
}
```

**Second: Integrate with CI/CD pipelines:**

**[SCREEN: GitHub Actions YAML]**
```yaml
name: Update Production Secrets
on:
  workflow_dispatch:
    inputs:
      secret_version:
        description: 'Secret version number'
        required: true
        type: number

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - name: Update Secrets
      run: |
        terraform apply \
          -var="secret_version=${{ github.event.inputs.secret_version }}" \
          -var="secret_data=${{ secrets.DATABASE_PASSWORD }}"
```

**HOST:** **Third: Use with external secret management systems:**

**[TYPING]**
```hcl
# Read from external source
data "external" "app_secrets" {
  program = ["vault", "kv", "get", "-format=json", "secret/myapp"]
}

resource "vault_kv_secret_v2" "app_secrets" {
  mount                = vault_mount.secrets.path
  name                 = "application-secrets"
  data_json_wo         = data.external.app_secrets.result.data
  data_json_wo_version = var.deployment_version
}
```

**HOST:** This pattern lets you pull secrets from any external system - AWS Secrets Manager, Azure Key Vault, 1Password, whatever you're using - and inject them into Terraform without state file exposure.

### [14:15 - 15:30] MIGRATION STRATEGY

**[SCREEN: Migration phases diagram]**

**HOST:** If you're already using Terraform with secrets, here's how to migrate safely:

**Phase 1: Audit your current secret usage**
```bash
# Find all sensitive attributes in your state
terraform state list | xargs -I {} terraform state show {} | grep -i "password\|secret\|key\|token"
```

**Phase 2: Gradual migration - run both old and new attributes temporarily:**
```hcl
resource "vault_kv_secret_v2" "migration_example" {
  mount = vault_mount.secrets.path
  name  = "migration-test"
  
  # Keep existing during transition
  data_json = jsonencode(var.secrets)
  
  # Add new write-only version
  data_json_wo         = jsonencode(var.secrets)
  data_json_wo_version = var.secret_version
}
```

**Phase 3: Remove old attributes and update all workflows**

**[SCREEN: Current provider support]**

**HOST:** Right now, the Vault provider leads the way with support for:
- `vault_kv_secret_v2.data_json_wo`
- `vault_database_secret_backend_connection.password_wo`  
- `vault_gcp_secret_backend.credentials_wo`

But expect this to expand rapidly across the entire Terraform ecosystem.

### [15:30 - 16:30] WRAP-UP & NEXT STEPS

**[SCREEN: Summary points]**

**HOST:** Let's wrap up with why this is such a game changer:

**Security Impact:**
- No more secrets in state files - ever
- Reduced attack surface 
- Easier compliance and auditing
- True GitOps for secrets

**Operational Benefits:**
- Better CI/CD integration
- Seamless secret rotation
- Works with any secret management system
- No breaking changes to existing workflows

**[SCREEN: Upgrade checklist]**

**Your next steps:**
1. Ensure you have Terraform 1.11+ (this demo uses v1.12.1)
2. Update your provider versions (Vault 5.0+ for these features)
3. Start with a non-production test using our demo
4. Plan your migration strategy
5. Update your CI/CD pipelines

**[SCREEN: Links and resources]**

I've put all the example code in the description, along with links to the official documentation. This is honestly the biggest security improvement in Terraform since sensitive variables were introduced.

The future of Infrastructure as Code is more secure, and it starts with write-only attributes. Trust me, your security team will thank you for this.

What questions do you have about write-only attributes? Drop them in the comments below, and if this helped you out, smash that like button and subscribe for more DevOps content.

Until next time, keep your infrastructure secure and your secrets out of state files!

---

## POST-PRODUCTION NOTES:

### Visual Elements to Include:
1. **Split-screen comparisons** showing state files before/after
2. **Animated diagrams** explaining the write-only concept
3. **Code highlighting** for key syntax differences
4. **Terminal recordings** showing real terraform plan/apply output
5. **Security vulnerability visualization** showing exposed vs protected secrets

### Call-to-Action Cards:
1. Subscribe button at 2:00 mark
2. Like reminder at 10:00 mark
3. Related video suggestions at end
4. GitHub repository link overlay

### SEO Keywords:
- Terraform 1.11
- Write-only attributes
- Terraform secrets
- HashiCorp Vault
- Infrastructure as Code security
- Terraform state file security
- DevOps security best practices

### Related Video Topics:
1. "Complete Terraform Security Guide 2024"
2. "HashiCorp Vault Integration with Terraform"
3. "Terraform State File Security Deep Dive"
4. "GitOps Secrets Management Strategies"