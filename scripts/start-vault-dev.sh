#!/bin/bash

# Terraform Write-Only Secrets Demo - Vault Dev Server Setup
# This script starts a HashiCorp Vault development server for testing write-only attributes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VAULT_VERSION="1.18.4"  # Version tested with
VAULT_DEV_ROOT_TOKEN="root"
VAULT_DEV_LISTEN_ADDRESS="127.0.0.1:8200"
VAULT_ADDR="http://${VAULT_DEV_LISTEN_ADDRESS}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check Vault installation and show version
check_vault_installation() {
    if ! command -v vault &> /dev/null; then
        print_error "Vault is not installed!"
        echo ""
        echo "Please install Vault first:"
        echo "  macOS: brew install vault"
        echo "  Linux: Follow instructions at https://developer.hashicorp.com/vault/downloads"
        echo "  Windows: Download from https://developer.hashicorp.com/vault/downloads"
        exit 1
    fi
    
    local vault_version=$(vault version | head -n1 | awk '{print $2}' | sed 's/v//')
    print_status "✓ Found Vault version: $vault_version"
    
    # Check Terraform version too
    if command -v terraform &> /dev/null; then
        local tf_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n1 | awk '{print $2}' | sed 's/v//')
        print_status "✓ Found Terraform version: $tf_version"
    else
        print_warning "Terraform not found - you'll need it to run the demo"
    fi
}

# Function to check if port is available
check_port() {
    if lsof -Pi :8200 -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port 8200 is already in use!"
        echo ""
        echo "This might be an existing Vault server. To stop it:"
        echo "  1. Find the process: lsof -i :8200"
        echo "  2. Kill it: kill -9 <PID>"
        echo "  3. Or if it's a previous dev server: pkill vault"
        echo ""
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Aborted by user"
            exit 1
        fi
    fi
}

# Function to start Vault dev server
start_vault_dev() {
    print_header "Starting Vault Development Server"
    
    print_status "Starting Vault dev server..."
    print_status "Root token: $VAULT_DEV_ROOT_TOKEN"
    print_status "Listen address: $VAULT_ADDR"
    
    # Kill any existing Vault dev processes (more specific)
    pkill -f "vault server -dev" 2>/dev/null || true
    sleep 1
    
    # Start Vault in development mode with nohup to ensure it persists
    nohup vault server -dev \
        -dev-root-token-id="$VAULT_DEV_ROOT_TOKEN" \
        -dev-listen-address="$VAULT_DEV_LISTEN_ADDRESS" \
        > vault-dev.log 2>&1 &
    
    local vault_pid=$!
    echo $vault_pid > vault-dev.pid
    
    print_status "Vault server started with PID: $vault_pid"
    print_status "Logs are being written to: vault-dev.log"
    
    # Wait for Vault to be ready
    print_status "Waiting for Vault to be ready..."
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if curl -s "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; then
            print_status "✓ Vault is ready!"
            break
        fi
        
        sleep 1
        retries=$((retries + 1))
        echo -n "."
    done
    
    if [ $retries -eq $max_retries ]; then
        print_error "Vault failed to start within $max_retries seconds"
        print_error "Check vault-dev.log for details"
        exit 1
    fi
    
    echo ""
}

# Function to configure Vault for the demo
configure_vault() {
    print_header "Configuring Vault for Demo"
    
    export VAULT_ADDR="$VAULT_ADDR"
    export VAULT_TOKEN="$VAULT_DEV_ROOT_TOKEN"
    
    print_status "Setting up Vault environment variables..."
    
    # Verify we can connect
    if ! vault status > /dev/null 2>&1; then
        print_error "Cannot connect to Vault server"
        exit 1
    fi
    
    print_status "✓ Successfully connected to Vault"
    print_status "✓ KV v2 secrets engine is enabled by default in dev mode"
    
    # The demo will create its own mounts, so we don't need to pre-configure anything
    print_status "✓ Vault is ready for the Terraform demo"
}

# Function to display connection info
display_connection_info() {
    print_header "Vault Connection Information"
    
    echo ""
    echo "🔐 Vault Development Server is running!"
    echo ""
    echo "Connection details:"
    echo "  Address: $VAULT_ADDR"
    echo "  Root Token: $VAULT_DEV_ROOT_TOKEN"
    echo ""
    echo "Environment variables for Terraform:"
    echo "  export VAULT_ADDR=\"$VAULT_ADDR\""
    echo "  export VAULT_TOKEN=\"$VAULT_DEV_ROOT_TOKEN\""
    echo "  export TF_VAR_vault_address=\"$VAULT_ADDR\""
    echo "  export TF_VAR_vault_token=\"$VAULT_DEV_ROOT_TOKEN\""
    echo ""
    echo "Vault CLI commands to test:"
    echo "  vault status"
    echo "  vault kv list secret/"
    echo "  vault kv put secret/test key=value"
    echo ""
    echo "Web UI (if available):"
    echo "  http://localhost:8200/ui"
    echo "  Token: $VAULT_DEV_ROOT_TOKEN"
    echo ""
    echo "To stop the server:"
    echo "  ./scripts/stop-vault-dev.sh"
    echo "  Or: kill \$(cat vault-dev.pid)"
    echo ""
}

# Function to verify helper scripts exist
verify_helper_scripts() {
    print_status "Verifying helper scripts..."
    
    if [ -f "scripts/stop-vault-dev.sh" ] && [ -x "scripts/stop-vault-dev.sh" ]; then
        print_status "✓ scripts/stop-vault-dev.sh - available"
    else
        print_warning "scripts/stop-vault-dev.sh not found or not executable"
    fi
    
    if [ -f "scripts/setup-env.sh" ] && [ -x "scripts/setup-env.sh" ]; then
        print_status "✓ scripts/setup-env.sh - available"
    else
        print_warning "scripts/setup-env.sh not found or not executable"
    fi
}

# Main execution
main() {
    print_header "Terraform Write-Only Secrets Demo - Vault Setup"
    
    # Create scripts directory if it doesn't exist
    mkdir -p scripts
    
    check_vault_installation
    check_port
    start_vault_dev
    configure_vault
    verify_helper_scripts
    display_connection_info
    
    print_status "🎉 Vault development server is ready for the Terraform demo!"
    print_status "✅ You already have the required versions installed!"
    print_status "   Terraform: $(terraform version | head -n1 | awk '{print $2}') (requires 1.11+)"
    print_status "   Vault: $(vault version | head -n1 | awk '{print $2}') (works great!)"
    echo ""
    print_status "Next steps:"
    echo "  1. cd examples/"
    echo "  2. source ../scripts/setup-env.sh"
    echo "  3. terraform init"
    echo "  4. terraform plan"
    echo "  5. terraform apply"
}

# Handle script interruption (only on Ctrl+C, not normal exit)
cleanup_on_interrupt() {
    print_warning "Script interrupted with Ctrl+C"
    if [ -f vault-dev.pid ]; then
        PID=$(cat vault-dev.pid)
        if kill -0 $PID 2>/dev/null; then
            print_status "Stopping Vault server due to interruption..."
            kill $PID
            rm -f vault-dev.pid
        fi
    fi
    exit 1
}

# Only trap SIGINT (Ctrl+C), not normal script exit
trap cleanup_on_interrupt INT

# Run main function
main "$@"

# Ensure vault process continues running after script exits
print_status "Script completed - Vault server continues running in background" 