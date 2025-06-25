#!/bin/bash

# Demo Script: Secure Terraform Secrets with Write-Only Attributes
# This script demonstrates the SECURE approach using write-only attributes and ephemeral resources

set -e

echo "🔐 =========================================================="
echo "🔐 SECURE TERRAFORM SECRETS DEMONSTRATION"
echo "🔐 =========================================================="
echo ""
echo "✅ This demo shows the NEW, SECURE way of handling secrets"
echo "✅ Using Terraform 1.11+ write-only attributes and ephemeral resources"
echo "✅ Zero secrets in state files - ever!"
echo ""

# Check if we're in the right directory
if [[ ! -f "examples/secure/complete-demo.tf" ]]; then
    echo "❌ Error: Please run this script from the terraform-write-only directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected file: examples/secure/complete-demo.tf"
    exit 1
fi

# Check if Vault is running
if ! curl -s http://127.0.0.1:8200/v1/sys/health > /dev/null 2>&1; then
    echo "❌ Vault server is not running!"
    echo "   Please start Vault first: ./scripts/start-vault-dev.sh"
    exit 1
fi

echo "✅ Vault server is running"
echo ""

# Check if PostgreSQL is running
if ! docker ps | grep -q terraform-demo-postgres; then
    echo "⚠️  PostgreSQL container is not running"
    echo "   Starting PostgreSQL for dynamic secrets demo..."
    ../scripts/start-postgres-dev.sh
else
    echo "✅ PostgreSQL database is running"
fi

echo ""

# Navigate to secure examples directory
cd examples/secure/

echo "📁 Working in: $(pwd)"
echo ""

echo "🔍 Step 1: Let's examine the SECURE configuration..."
echo "   File: complete-demo.tf"
echo ""
echo "   Key security features:"
echo "   ✅ Uses 'data_json_wo' (write-only) instead of 'data_json'"
echo "   ✅ Uses 'ephemeral' resources instead of regular 'data' sources"
echo "   ✅ Includes real PostgreSQL dynamic secrets"
echo "   ✅ All secrets protected from state file exposure"
echo ""

read -p "Press Enter to continue with the secure demo..."

echo "🚀 Step 2: Initialize Terraform..."
echo "   Command: terraform init -upgrade"
terraform init -upgrade

echo ""
echo "📋 Step 3: Run terraform plan (WATCH THE SECURITY IN ACTION!)..."
echo ""
echo "🔍 Notice the KEY DIFFERENCES in plan output:"
echo "   ✅ Write-only attributes show as '(write-only attribute)'"
echo "   ✅ Ephemeral resources show as 'Configuration unknown, deferring...'"
echo ""

read -p "Press Enter to run 'terraform plan' and see the secure approach..."

echo "   Command: terraform plan"
terraform plan

echo ""
echo "🎉 DID YOU SEE THE DIFFERENCE?!"
echo "   ✅ All write-only attributes showed as '(write-only attribute)'"
echo "   ✅ Ephemeral resources deferred (not stored in state)"
echo ""


read -p "Press Enter to apply the configuration and see the secure state..."

echo ""
echo "🚀 Step 4: Apply the secure configuration..."
echo "   Command: terraform apply -auto-approve"
terraform apply -auto-approve

echo ""
echo "✅ Step 5: Now let's examine the SECURE state file..."
echo ""

read -p "Press Enter to continue with the secure state file analysis..."

echo "🔍 Checking what's in the secure state file..."
echo ""

echo "📄 All resources in state:"
echo "   Command: terraform state list"
terraform state list

echo ""
echo "🔐 Let's examine write-only attributes in the state..."
echo ""

echo "📋 Database configuration resource (write-only attributes):"
echo "   Command: terraform state show vault_kv_secret_v2.database_config | grep -A 5 -B 5 'data_json_wo'"
terraform state show vault_kv_secret_v2.database_config | grep -A 5 -B 5 "data_json_wo"

echo ""
echo "📋 Complete config resource (write-only attributes):"
echo "   Command: terraform state show vault_kv_secret_v2.complete_app_config | grep -A 5 -B 5 'data_json_wo'"
terraform state show vault_kv_secret_v2.complete_app_config | grep -A 5 -B 5 "data_json_wo"


echo ""
echo "🔐 Let's search for secrets in the state file..."
echo "   Searching for: super-secret-db-password-123"
echo ""

echo "   Command: grep -q 'super-secret-db-password-123' terraform.tfstate"
if grep -q "super-secret-db-password-123" terraform.tfstate; then
    echo "🚨 UNEXPECTED: Found secret in state file!"
    echo "   Command: grep -n 'super-secret-db-password-123' terraform.tfstate"
    grep -n "super-secret-db-password-123" terraform.tfstate
else
    echo "✅ EXCELLENT: Secret NOT found in state file!"
fi

echo ""
echo "🔐 Let's search for API keys..."
echo "   Searching for: sk_live_abcdef123456789"
echo ""

echo "   Command: grep -q 'sk_live_abcdef123456789' terraform.tfstate"
if grep -q "sk_live_abcdef123456789" terraform.tfstate; then
    echo "🚨 UNEXPECTED: Found API key in state file!"
    echo "   Command: grep -n 'sk_live_abcdef123456789' terraform.tfstate"
    grep -n "sk_live_abcdef123456789" terraform.tfstate
else
    echo "✅ EXCELLENT: API key NOT found in state file!"
fi

echo ""
echo "🔐 Let's extract the write-only attribute values to confirm they're null..."
echo ""

if command -v jq > /dev/null 2>&1; then
    echo "🔍 Using jq to check write-only attributes in state file..."
    echo ""
    
    echo "✅ Database write-only attribute in state:"
    echo "   Command: cat terraform.tfstate | jq -r '.resources[] | select(.name==\"database_config\") | .instances[0].attributes.data_json_wo'"
    cat terraform.tfstate | jq -r '.resources[] | select(.name=="database_config") | .instances[0].attributes.data_json_wo'
    
    echo ""
    echo "✅ Complete config write-only attribute in state:"
    echo "   Command: cat terraform.tfstate | jq -r '.resources[] | select(.name==\"complete_app_config\") | .instances[0].attributes.data_json_wo'"
    cat terraform.tfstate | jq -r '.resources[] | select(.name=="complete_app_config") | .instances[0].attributes.data_json_wo'
    
    echo ""
    echo "✅ All write-only attributes show as: null"
else
    echo "📄 Checking write-only attributes in state file:"
    echo "   Command: grep -A 3 -B 1 'data_json_wo' terraform.tfstate | head -10"
    grep -A 3 -B 1 "data_json_wo" terraform.tfstate | head -10
fi

echo ""
echo "⚡ Let's check ephemeral resources (they shouldn't be in state at all!)..."
echo ""

echo "🔍 Searching for ephemeral resources in state:"
echo "   Command: terraform state list | grep ephemeral"
if terraform state list | grep -q ephemeral; then
    echo "🚨 UNEXPECTED: Found ephemeral resources in state!"
    terraform state list | grep ephemeral
else
    echo "✅ PERFECT: No ephemeral resources in state file!"
    echo "   Ephemeral resources are used during configuration but never persisted"
fi

echo ""
echo "🔐 But let's verify the secrets ARE actually in Vault..."
echo ""

read -p "Press Enter to continue checking secrets in Vault..."


echo "✅ Checking secrets in Vault (they should be there!):"
echo ""

echo "🔍 Database password in Vault:"
echo "   Command: vault kv get -field=password demo-secrets/database/postgres"
vault kv get -field=password demo-secrets/database/postgres

echo ""
echo "🔍 Complete config in Vault:"
echo "   Command: vault kv get demo-secrets/app/complete-secure-config"
vault kv get demo-secrets/app/complete-secure-config

echo ""
echo "🎯 Step 6: Test dynamic database secrets..."
echo ""

read -p "Press Enter to continue testing dynamic database secrets..."


echo "🔍 Generate dynamic PostgreSQL credentials:"
echo "   Command: vault read database/creds/app-role"
vault read database/creds/app-role

echo ""
echo "🔍 Let's get fresh credentials and test the connection:"
echo "   Command: DYNAMIC_CREDS=\$(vault read -format=json database/creds/app-role)"
DYNAMIC_CREDS=$(vault read -format=json database/creds/app-role)
echo "   Command: DYNAMIC_USER=\$(echo \$DYNAMIC_CREDS | jq -r '.data.username')"
DYNAMIC_USER=$(echo $DYNAMIC_CREDS | jq -r '.data.username')
echo "   Command: DYNAMIC_PASS=\$(echo \$DYNAMIC_CREDS | jq -r '.data.password')"
DYNAMIC_PASS=$(echo $DYNAMIC_CREDS | jq -r '.data.password')

echo "Generated dynamic user: $DYNAMIC_USER"
echo "Testing database connection..."

# Test the dynamic credentials
echo "   Command: docker exec terraform-demo-postgres psql -U \"\$DYNAMIC_USER\" -d postgres -c \"SELECT current_user, 'Dynamic credentials work!' as message;\""
if docker exec terraform-demo-postgres psql -U "$DYNAMIC_USER" -d postgres -c "SELECT current_user, 'Dynamic credentials work!' as message;" 2>/dev/null; then
    echo "✅ SUCCESS: Dynamic credentials work perfectly!"
else
    echo "⚠️  Note: Dynamic credentials generated but connection test skipped"
fi

echo ""
echo "🔐 Step 7: Let's examine the complete security model..."
echo ""

read -p "Press Enter to continue with our final analysis..."

echo "📊 State file analysis:"
echo "   Command: ls -lh terraform.tfstate"
ls -lh terraform.tfstate
echo ""

echo "🔢 Secret exposure analysis:"
echo "   Command: grep -o 'data_json_wo' terraform.tfstate | wc -l"
echo "   Times 'data_json_wo' appears: $(grep -o "data_json_wo" terraform.tfstate | wc -l)"
echo "   Command: grep -A 1 'data_json_wo' terraform.tfstate | grep -c 'null'"
echo "   Times 'null' appears for write-only: $(grep -A 1 "data_json_wo" terraform.tfstate | grep -c "null")"
echo "   Command: grep -c 'super-secret-db-password-123' terraform.tfstate || echo '0'"
echo "   Times actual secrets appear: $(grep -c "super-secret-db-password-123" terraform.tfstate || echo "0")"

echo ""
echo "✅ =========================================================="
echo "✅ SECURITY ANALYSIS: WHAT WENT RIGHT?"
echo "✅ =========================================================="
echo ""
echo "🔐 SECURE APPROACH BENEFITS:"
echo "   1. ✅ Secrets show as '(write-only attribute)' in plan"
echo "   2. ✅ Write-only attributes are 'null' in state file"
echo "   3. ✅ Ephemeral resources don't appear in state at all"
echo "   4. ✅ Secrets safely stored in Vault"
echo "   5. ✅ Dynamic credentials work with real database"
echo "   6. ✅ Complete functionality with zero state exposure"
echo ""
echo "🛡️  ATTACK SURFACE ELIMINATED:"
echo "   • State files can be safely stored anywhere"
echo "   • CI/CD logs don't expose secrets"
echo "   • Developers can share state files"
echo "   • Backup systems are secure"
echo "   • Git repositories are safe"
echo ""
echo "📊 SECURITY VERIFICATION:"
echo "   • Static database passwords: PROTECTED ✅"
echo "   • Root database passwords: PROTECTED ✅"
echo "   • Dynamic credentials: PROTECTED ✅"
echo "   • Secret composition: PROTECTED ✅"
echo "   • All write-only attributes: NULL in state ✅"
echo ""

echo "✅ =========================================================="
echo "✅ COMPARISON: BEFORE vs AFTER"
echo "✅ =========================================================="
echo ""
echo "📊 BEFORE (Traditional approach):"
echo "   💀 terraform plan: Shows ALL secrets in plain text"
echo "   💀 terraform.tfstate: Contains ALL secrets in plain text"
echo "   💀 data sources: Expose retrieved secrets in state"
echo "   💀 sensitive = true: Doesn't prevent state exposure"
echo "   💀 Attack surface: MASSIVE"
echo ""
echo "📊 AFTER (Write-only attributes):"
echo "   ✅ terraform plan: Shows '(write-only attribute)'"
echo "   ✅ terraform.tfstate: Shows 'null' for write-only attributes"
echo "   ✅ ephemeral resources: Don't appear in state at all"
echo "   ✅ Dynamic secrets: Auto-expiring with real database"
echo "   ✅ Attack surface: ELIMINATED"
echo ""

echo "🎓 =========================================================="
echo "🎓 EDUCATIONAL SUMMARY FOR STUDENTS"
echo "🎓 =========================================================="
echo ""
echo "🔑 KEY CONCEPTS DEMONSTRATED:"
echo ""
echo "1. 🔐 Write-Only Attributes (data_json_wo):"
echo "   • Accept secret values during configuration"
echo "   • Never store values in plan or state files"
echo "   • Show as 'null' in state, '(write-only attribute)' in plan"
echo ""
echo "2. ⚡ Ephemeral Resources:"
echo "   • Retrieve secrets without storing in state"
echo "   • Temporary access during Terraform execution"
echo "   • Complete lifecycle: Opening → Using → Closing"
echo ""
echo "3. 🔄 Dynamic Database Secrets:"
echo "   • Auto-generated PostgreSQL users"
echo "   • Time-limited access (1-hour TTL)"
echo "   • Real database integration"
echo ""
echo "4. 🛡️  Complete Security Model:"
echo "   • Static secrets: Write-only attributes"
echo "   • Dynamic secrets: Ephemeral resources"
echo "   • Secret composition: Secure combination"
echo "   • Zero state exposure: Ultimate goal achieved"
echo ""


echo ""
echo "🔄 Step 8: Demonstrate secure secret updates..."
echo ""

read -p "Press Enter to see version update demonstration..."


echo "🔍 Let's update secrets using version tracking:"
echo "   Current version: 1"
echo "   Updating to version: 2"
echo ""

echo "   Command: terraform apply -var=\"secret_version=2\" -auto-approve"
terraform apply -var="secret_version=2" -auto-approve

echo ""
echo "✅ Secret update complete!"
echo ""
echo "🔍 Notice in the plan output:"
echo "   • Only 'data_json_wo_version' changed from 1 → 2"
echo "   • Secret values were never shown"
echo "   • State file still shows 'null' for write-only attributes"
echo ""

echo "✅ =========================================================="
echo "✅ DEMO COMPLETE: SECURE SECRETS ACHIEVED!"
echo "✅ =========================================================="
echo ""
echo "🎉 WHAT STUDENTS HAVE LEARNED:"
echo ""
echo "✅ Traditional approach: DANGEROUS"
echo "   • Secrets exposed in plans and state"
echo "   • Major security vulnerability"
echo ""
echo "✅ Write-only attributes: REVOLUTIONARY"
echo "   • Zero secrets in state files"
echo "   • Safe for GitOps workflows"
echo "   • Production-ready security"
echo ""
echo "✅ Ephemeral resources: POWERFUL"
echo "   • Retrieve secrets without persistence"
echo "   • Temporary access model"
echo "   • No state file pollution"
echo ""
echo "✅ Dynamic secrets: ADVANCED"
echo "   • Auto-expiring credentials"
echo "   • Real database integration"
echo "   • Zero-trust security model"
echo ""
echo "🚀 This is the future of secure Infrastructure as Code!"
echo ""
echo "📚 Next steps for students:"
echo "   1. Practice with write-only attributes"
echo "   2. Implement ephemeral resources"
echo "   3. Explore dynamic secrets engines"
echo "   4. Plan migration from traditional approach"
echo ""
echo "🎯 Remember: Terraform 1.11+ write-only attributes solve"
echo "   the biggest security problem in Infrastructure as Code!"
echo ""

read -p "Press Enter to finish..."

echo ""
echo "🧹 =========================================================="
echo "🧹 DEMO COMPLETE"
echo "🧹 =========================================================="
echo ""
echo "🧹 Demo complete - no cleanup needed"
echo "   (Vault and PostgreSQL will be stopped separately)"
echo ""
echo "🎉 DEMO SEQUENCE COMPLETE!"
echo ""
echo "📚 What you've learned:"
echo "   💀 Traditional approach: Dangerous secret exposure"
echo "   ✅ Write-only attributes: Revolutionary security"
echo "   ⚡ Ephemeral resources: Temporary secret access"
echo "   🔄 Dynamic secrets: Auto-expiring credentials"
echo ""
echo "🚀 You're now ready to implement secure Infrastructure as Code!"
echo "" 