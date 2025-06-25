#!/bin/bash

# Demo Script: Insecure Terraform Secrets (Educational)
# This script demonstrates the DANGEROUS traditional approach to secrets in Terraform
# ⚠️  FOR EDUCATIONAL PURPOSES ONLY - DO NOT USE IN PRODUCTION!

set -e

echo "🚨 =========================================================="
echo "🚨 INSECURE TERRAFORM SECRETS DEMONSTRATION"
echo "🚨 =========================================================="
echo ""
echo "⚠️  WARNING: This demo shows the OLD, DANGEROUS way of handling secrets"
echo "⚠️  This is for educational purposes only!"
echo "⚠️  After this demo, we'll show the SECURE approach with write-only attributes"
echo ""

# Check if we're in the right directory
if [[ ! -f "examples/insecure/insecure-demo.tf" ]]; then
    echo "❌ Error: Please run this script from the terraform-write-only directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected file: examples/insecure/insecure-demo.tf"
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

# Navigate to insecure examples directory
cd examples/insecure/

echo "📁 Working in: $(pwd)"
echo ""

echo "🔍 Step 1: Let's look at the INSECURE configuration..."
echo "   File: insecure-demo.tf"
echo ""
echo "   Key differences from secure approach:"
echo "   ❌ Uses 'data_json' instead of 'data_json_wo'"
echo "   ❌ Uses regular 'data' sources instead of 'ephemeral'"
echo "   ❌ All secrets will be exposed in state file"
echo ""

read -p "Press Enter to continue with the insecure demo..."

echo "🚀 Step 2: Initialize Terraform..."
echo "   Command: terraform init -upgrade"
terraform init -upgrade

echo ""
echo "📋 Step 3: Run terraform plan (notice the 'sensitive value' masking)..."
echo ""
echo "🔍 You'll notice that Terraform shows '(sensitive value)' in the plan:"
echo "   - This gives a false sense of security!"
echo "   - The plan looks safe, but the STATE FILE is not!"
echo "   - The real problem is what gets stored after apply"
echo ""

read -p "Press Enter to run 'terraform plan' and see the deceptive output..."

echo "   Command: terraform plan"
terraform plan

echo ""
echo "🤔 THAT LOOKED SAFE, RIGHT? WRONG!"
echo "   ✅ Plan shows '(sensitive value)' - looks secure"
echo "   ❌ But the STATE FILE will contain everything in plain text!"
echo ""

read -p "Press Enter to apply the configuration and expose the REAL security problem..."

echo ""
echo "🚀 Step 4: Apply the configuration (this is where the danger happens)..."
echo "   Command: terraform apply -auto-approve"
terraform apply -auto-approve

read -p "Press Enter to check the state file..."

echo ""
echo "💀 Step 5: Now let's examine the SECURITY NIGHTMARE in the state file..."
echo ""

echo "🔍 Checking what's in the state file..."
echo ""

echo "📄 All resources in state:"
echo "   Command: terraform state list"
terraform state list

echo ""
echo "💀 Let's examine a specific resource to see ALL the exposed secrets..."
echo ""

echo "📋 Database configuration resource (contains static secrets):"
echo "   Command: terraform state show vault_kv_secret_v2.insecure_database_config | head -15"
terraform state show vault_kv_secret_v2.insecure_database_config | head -15

echo ""
echo "📋 Database connection resource (contains root password):"
echo "   Command: terraform state show vault_database_secret_backend_connection.insecure_postgres | head -15"
terraform state show vault_database_secret_backend_connection.insecure_postgres | head -15
echo ""

echo ""
echo "💀 NOW LET'S SEE THE REAL PROBLEM - RAW STATE FILE ACCESS!"
echo "   (This is what attackers/anyone with state file access can do)"
echo ""

echo ""
echo "💀 Let's search for our 'secret' database password in the state file..."
echo "   Searching for: super-secret-db-password-123"
echo ""

echo "   Command: grep -q 'super-secret-db-password-123' terraform.tfstate"
if grep -q "super-secret-db-password-123" terraform.tfstate; then
    echo "🚨 FOUND IT! The secret password is in the state file:"
    echo "   Command: grep -n 'super-secret-db-password-123' terraform.tfstate"
    grep -n "super-secret-db-password-123" terraform.tfstate
else
    echo "🤔 Not found with simple grep, let's check the JSON structure..."
fi

echo ""
echo "Or we can use jq to extract the secrets from the state file"
echo ""

if command -v jq > /dev/null 2>&1; then
    echo "🔍 Using jq to extract secrets from raw state file..."
    echo ""
    
    echo "💀 Static database secrets in raw state file:"
    echo "   Command: cat terraform.tfstate | jq -r '.resources[] | select(.name==\"insecure_database_config\") | .instances[0].attributes.data_json' | jq ."
    cat terraform.tfstate | jq -r '.resources[] | select(.name=="insecure_database_config") | .instances[0].attributes.data_json' | jq .
    
    echo ""
    echo "💀 Root database password in raw state file:"
    echo "   Command: cat terraform.tfstate | jq -r '.resources[] | select(.name==\"insecure_postgres\") | .instances[0].attributes.postgresql[0].password'"
    cat terraform.tfstate | jq -r '.resources[] | select(.name=="insecure_postgres") | .instances[0].attributes.postgresql[0].password'
else
    echo "📄 Raw state file content (showing secrets in JSON):"
    echo "   Command: grep 'super-secret-db-password-123' terraform.tfstate"
    grep -n "super-secret-db-password-123" terraform.tfstate
fi

echo ""
echo "📏 Now let's look at the state file size and secret density:"
echo "   Command: ls -lh terraform.tfstate"
ls -lh terraform.tfstate
echo ""
echo "🔢 Number of times 'password' appears in state:"
echo "   Command: grep -o 'password' terraform.tfstate | wc -l"
grep -o "password" terraform.tfstate | wc -l
echo ""
echo "🔢 Number of times 'secret' appears in state:"
echo "   Command: grep -o 'secret' terraform.tfstate | wc -l"
grep -o "secret" terraform.tfstate | wc -l
echo ""
echo "🔢 Number of times our specific password appears in state:"
echo "   Command: grep -o 'super-secret-db-password-123' terraform.tfstate | wc -l"
grep -o "super-secret-db-password-123" terraform.tfstate | wc -l
echo ""

echo ""
echo "🚨 THERE IT IS! The 'sensitive value' masking is ONLY for display!"
echo "   ✅ Terraform commands show '(sensitive value)' - looks secure"
echo "   ❌ But grep finds our password 7+ times in the raw state file!"
echo "   ❌ Complete database credentials exposed in JSON format"

echo ""
echo "🚨 =========================================================="
echo "🚨 SECURITY ANALYSIS: WHAT WENT WRONG?"
echo "🚨 =========================================================="
echo ""
echo "💀 PROBLEMS WITH TRADITIONAL APPROACH:"
echo "   1. 🤔 Plan shows '(sensitive value)' - looks safe but isn't!"
echo "   2. 🤔 'terraform state show' shows '(sensitive value)' - also looks safe!"
echo "   3. ❌ BUT: Simple grep finds passwords 7+ times in state file!"
echo "   4. ❌ Raw JSON in state exposes complete database credentials"
echo "   5. ❌ Anyone with state file access can extract ALL secrets"
echo ""
echo "🎯 ATTACK VECTORS:"
echo "   • State files stored in version control (Git)"
echo "   • State files in CI/CD logs"
echo "   • Shared state backends (S3, Terraform Cloud)"
echo "   • Developer machines with state files"
echo "   • Backup systems containing state files"
echo ""
echo "📊 IMPACT ASSESSMENT:"
echo "   • Static database password: EXPOSED 7+ times in state file"
echo "   • Root database password: EXPOSED in multiple resources"
echo "   • Complete database credentials: EXPOSED in readable JSON"
echo "   • Production database access: FULLY COMPROMISED"
echo ""


echo "🚨 =========================================================="
echo "🚨 WHAT STUDENTS SHOULD UNDERSTAND"
echo "🚨 =========================================================="
echo ""
echo "🎓 KEY LEARNING POINTS:"
echo ""
echo "1. 💀 Traditional Terraform approach:"
echo "   • Plan/state commands show '(sensitive value)' - FALSE SECURITY!"
echo "   • Simple grep reveals passwords 7+ times in state file"
echo "   • Complete credentials exposed in readable JSON format"
echo ""
echo "2. 🔐 Write-only attributes approach:"
echo "   • Static secrets: data_json_wo never in state"
echo "   • Dynamic secrets: password_wo protects root credentials"
echo "   • State shows 'null' for all write-only attributes"
echo ""
echo "3. ⚡ Ephemeral resources:"
echo "   • Read secrets without storing in state"
echo "   • Generate dynamic credentials temporarily"
echo "   • No persistence in state file"
echo ""

read -p "Press Enter to cleanup..."

echo "🚨 =========================================================="
echo "🚨 CLEANUP AND NEXT STEPS"
echo "🚨 =========================================================="
echo ""
echo "🧹 Cleaning up the insecure demo..."

# Destroy the insecure resources
echo "   Command: terraform destroy -auto-approve"
terraform destroy -auto-approve

echo ""
echo "✅ Insecure demo resources destroyed"
echo ""
echo "🎯 NEXT: Run the SECURE demo to see the solution!"
echo ""
echo "   ./scripts/demo-secure-secrets.sh"
echo ""
echo "🔐 In the secure demo, you'll see:"
echo "   ✅ Secrets shown as '(write-only attribute)' in plan"
echo "   ✅ State file shows 'null' for all write-only attributes"
echo "   ✅ Ephemeral resources don't appear in state at all"
echo "   ✅ Complete security without functionality loss"
echo ""
echo "🎉 This is why Terraform 1.11's write-only attributes are revolutionary!"
echo ""



