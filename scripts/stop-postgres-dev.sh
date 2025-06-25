#!/bin/bash

# Stop PostgreSQL Dev Database for Terraform Write-Only Secrets Demo

set -e

POSTGRES_CONTAINER_NAME="terraform-demo-postgres"

echo "🐘 Stopping PostgreSQL development database..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

# Check if container exists and is running
if docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
    echo "🛑 Stopping PostgreSQL container..."
    docker stop ${POSTGRES_CONTAINER_NAME}
    echo "✅ PostgreSQL container stopped"
else
    echo "ℹ️  PostgreSQL container is not running"
fi

# Optionally remove the container (uncomment if you want to clean up completely)
# echo "🗑️  Removing PostgreSQL container..."
# docker rm ${POSTGRES_CONTAINER_NAME} 2>/dev/null || true

echo ""
echo "🎉 PostgreSQL development database stopped!"
echo ""
echo "🛠️  Useful Commands:"
echo "   Start again: ./scripts/start-postgres-dev.sh"
echo "   Remove container: docker rm ${POSTGRES_CONTAINER_NAME}"
echo "   View logs: docker logs ${POSTGRES_CONTAINER_NAME}"
echo "" 