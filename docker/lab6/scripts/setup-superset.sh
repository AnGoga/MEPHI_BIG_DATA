#!/bin/bash

# Setup Apache Superset database connections for MOEX data pipeline
# This script configures Hive and Pinot connections

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "Setting up Apache Superset for Lab 6"
echo "=================================================="
echo ""

# Check if Superset is running
echo "⏳ Waiting for Superset to be ready..."
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8089/health > /dev/null 2>&1; then
        echo "✅ Superset is ready!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "❌ Error: Superset did not start in time"
        exit 1
    fi

    echo "   Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo ""

# Install required drivers in Superset container
echo "📦 Installing database drivers in Superset..."

docker exec superset pip install -q pyhive[hive] thrift thrift-sasl pinotdb 2>&1 | grep -v "already satisfied" || echo "   ✅ Drivers ready"

echo "✅ Drivers installed!"
echo ""

# Copy and run the database setup script
echo "🔗 Creating database connections..."

docker cp "$SCRIPT_DIR/setup_superset_databases.py" superset:/tmp/setup_databases.py

docker exec superset python /tmp/setup_databases.py

echo ""
echo "=================================================="
echo "✅ Superset setup completed!"
echo "=================================================="
echo ""
echo "Access Superset:"
echo "  URL: http://localhost:8089"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Available data sources:"
echo "  1. Apache Hive (Batch Data)"
echo "     - Database: moex_data"
echo "     - Tables: trades, trade_volumes_hourly"
echo ""
echo "  2. Apache Pinot (Streaming Data)"
echo "     - Table: current_prices"
echo ""
echo "Next steps:"
echo "  1. Login to Superset"
echo "  2. Go to SQL Lab to test queries"
echo "  3. Create visualizations and dashboards"
echo ""
