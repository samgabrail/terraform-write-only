#!/bin/bash

# Stop Vault development server

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🛑 Stopping Vault Development Server"
echo ""

if [ -f vault-dev.pid ]; then
    PID=$(cat vault-dev.pid)
    if kill -0 $PID 2>/dev/null; then
        print_status "Stopping Vault server (PID: $PID)..."
        kill $PID
        
        # Wait for process to stop
        retries=0
        while [ $retries -lt 10 ] && kill -0 $PID 2>/dev/null; do
            sleep 1
            retries=$((retries + 1))
        done
        
        if kill -0 $PID 2>/dev/null; then
            print_warning "Process still running, force killing..."
            kill -9 $PID 2>/dev/null
        fi
        
        rm -f vault-dev.pid
        print_status "✓ Vault server stopped"
    else
        print_warning "Vault server process not running (stale PID file)"
        rm -f vault-dev.pid
    fi
else
    print_warning "No Vault PID file found"
fi

# Clean up any remaining vault processes
VAULT_PROCESSES=$(pgrep -f "vault server -dev" 2>/dev/null || true)
if [ -n "$VAULT_PROCESSES" ]; then
    print_warning "Found lingering Vault processes, cleaning up..."
    pkill -f "vault server -dev" 2>/dev/null || true
    print_status "✓ Cleaned up any remaining Vault processes"
fi

# Clean up log files (optional)
if [ -f vault-dev.log ]; then
    print_status "Vault logs available in: vault-dev.log"
    echo "  To view: tail -f vault-dev.log"
    echo "  To remove: rm vault-dev.log"
fi

echo ""
print_status "🎉 Vault development server cleanup complete!" 