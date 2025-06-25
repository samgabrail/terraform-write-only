#!/bin/bash

# Set up environment variables for Terraform write-only secrets demo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

VAULT_ADDR="http://127.0.0.1:8200"
VAULT_TOKEN="root"

echo "🔧 Setting up environment for Terraform demo"
echo ""

# Check if Vault is running
if ! curl -s "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Vault server is not running at $VAULT_ADDR"
    echo ""
    echo "Please start Vault first:"
    echo "  ./scripts/start-vault-dev.sh"
    echo ""
    exit 1
fi

# Set environment variables
export VAULT_ADDR="$VAULT_ADDR"
export VAULT_TOKEN="$VAULT_TOKEN"
export TF_VAR_vault_address="$VAULT_ADDR"
export TF_VAR_vault_token="$VAULT_TOKEN"

echo -e "${GREEN}[INFO]${NC} ✓ Environment variables set:"
echo "  VAULT_ADDR=$VAULT_ADDR"
echo "  VAULT_TOKEN=$VAULT_TOKEN"
echo "  TF_VAR_vault_address=$VAULT_ADDR"
echo "  TF_VAR_vault_token=$VAULT_TOKEN"
echo ""

# Verify Vault connection
if vault status > /dev/null 2>&1; then
    echo -e "${GREEN}[INFO]${NC} ✓ Successfully connected to Vault"
    echo -e "${GREEN}[INFO]${NC} ✓ Vault version: $(vault version | head -n1 | awk '{print $2}')"
else
    echo -e "${YELLOW}[WARN]${NC} Could not verify Vault connection with CLI"
    echo "Environment variables are set, but please verify Vault is accessible"
fi

echo ""
echo -e "${GREEN}[INFO]${NC} 🎉 Ready to run Terraform demo!"
echo ""
echo "Next steps:"
echo "  cd examples/"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
echo ""
echo "To use these variables in your current shell session:"
echo "  source scripts/setup-env.sh" 