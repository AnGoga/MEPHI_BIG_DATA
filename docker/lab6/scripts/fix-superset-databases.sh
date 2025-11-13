#!/bin/bash

# Quick fix script to configure Superset database connections
# Run this if Superset UI shows no databases

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "🔧 Fixing Superset Database Connections"
echo "=========================================="
echo ""

# Check if Superset is running
if ! docker ps | grep -q superset; then
    echo "❌ Error: Superset container is not running"
    echo "   Start it first: cd docker/lab6 && docker compose up -d"
    exit 1
fi

echo "✅ Superset container is running"
echo ""

# Install required database drivers
echo "📦 Installing database drivers..."
docker exec superset pip install -q pinotdb pyhive[hive] thrift thrift-sasl 2>&1 | grep -v "already satisfied" || true
echo "✅ Drivers installed"
echo ""

# Copy the Python script into the container
echo "📋 Copying setup script to container..."
docker cp "$SCRIPT_DIR/setup_superset_databases.py" superset:/tmp/setup_databases.py
echo ""

# Run the setup script
echo "🚀 Configuring databases..."
echo ""
docker exec superset python /tmp/setup_databases.py

echo ""
echo "=========================================="
echo "✅ Database configuration completed!"
echo "=========================================="
echo ""
echo "🌐 Open Superset: http://localhost:8089"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "💡 Go to SQL Lab to test the connections"
echo ""
