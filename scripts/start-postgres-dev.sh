#!/bin/bash

# Start PostgreSQL Dev Database for Terraform Write-Only Secrets Demo
# This script starts a PostgreSQL container for testing dynamic database secrets

set -e

POSTGRES_CONTAINER_NAME="terraform-demo-postgres"
POSTGRES_PORT="5432"
POSTGRES_DB="postgres"
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="super-secret-db-password-123"  # Matches our Vault config

echo "🐘 Starting PostgreSQL development database..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please install Docker to run the PostgreSQL database"
    exit 1
fi

# Check if container already exists
if docker ps -a --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
    echo "📦 PostgreSQL container already exists"
    
    # Check if it's running
    if docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER_NAME}$"; then
        echo "✅ PostgreSQL is already running on port ${POSTGRES_PORT}"
        echo "   Connection: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
        exit 0
    else
        echo "🔄 Starting existing PostgreSQL container..."
        docker start ${POSTGRES_CONTAINER_NAME}
    fi
else
    echo "🚀 Creating new PostgreSQL container..."
    docker run -d \
        --name ${POSTGRES_CONTAINER_NAME} \
        -e POSTGRES_DB=${POSTGRES_DB} \
        -e POSTGRES_USER=${POSTGRES_USER} \
        -e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
        -p ${POSTGRES_PORT}:5432 \
        postgres:15-alpine
fi

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if docker exec ${POSTGRES_CONTAINER_NAME} pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB} > /dev/null 2>&1; then
        echo "✅ PostgreSQL is ready!"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        echo "❌ PostgreSQL failed to start within 30 seconds"
        echo "Check container logs: docker logs ${POSTGRES_CONTAINER_NAME}"
        exit 1
    fi
    
    echo "   Attempt $attempt/$max_attempts - waiting..."
    sleep 1
    ((attempt++))
done

# Create a test table for demonstration
echo "🏗️  Setting up demo database schema..."
docker exec -i ${POSTGRES_CONTAINER_NAME} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} << 'EOF'
-- Create a sample table for testing dynamic credentials
CREATE TABLE IF NOT EXISTS demo_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some sample data
INSERT INTO demo_users (username, email) VALUES 
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com')
ON CONFLICT (username) DO NOTHING;

-- Show current tables
\dt
EOF

echo ""
echo "🎉 PostgreSQL development database is ready!"
echo ""
echo "📋 Connection Details:"
echo "   Host: localhost"
echo "   Port: ${POSTGRES_PORT}"
echo "   Database: ${POSTGRES_DB}"
echo "   Username: ${POSTGRES_USER}"
echo "   Password: ${POSTGRES_PASSWORD}"
echo ""
echo "🔗 Connection URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
echo ""
echo "🛠️  Useful Commands:"
echo "   Connect: docker exec -it ${POSTGRES_CONTAINER_NAME} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
echo "   Stop: ./scripts/stop-postgres-dev.sh"
echo "   Logs: docker logs ${POSTGRES_CONTAINER_NAME}"
echo "" 