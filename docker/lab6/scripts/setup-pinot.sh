#!/bin/bash

# Setup Apache Pinot table for MOEX current prices
# This script creates schema and table in Pinot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "Setting up Apache Pinot for Lab 6"
echo "=================================================="
echo ""

# Check if Pinot Controller is running
echo "⏳ Waiting for Pinot Controller to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:9001/health > /dev/null 2>&1; then
        echo "✅ Pinot Controller is ready!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "❌ Error: Pinot Controller did not start in time"
        exit 1
    fi

    echo "   Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo ""

# Add schema
echo "📋 Creating Pinot schema: current_prices"
SCHEMA_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @"$PROJECT_ROOT/pinot-configs/current_prices_schema.json" \
    http://localhost:9001/schemas)

if echo "$SCHEMA_RESPONSE" | grep -q "error"; then
    echo "⚠️  Schema might already exist or there was an error:"
    echo "$SCHEMA_RESPONSE"
else
    echo "✅ Schema created successfully!"
fi

echo ""

# Add table
echo "📊 Creating Pinot table: current_prices (REALTIME)"
TABLE_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @"$PROJECT_ROOT/pinot-configs/current_prices_table.json" \
    http://localhost:9001/tables)

if echo "$TABLE_RESPONSE" | grep -q "error"; then
    echo "⚠️  Table might already exist or there was an error:"
    echo "$TABLE_RESPONSE"
else
    echo "✅ Table created successfully!"
fi

echo ""

# Verify table creation
echo "🔍 Verifying table creation..."
sleep 3

TABLES_RESPONSE=$(curl -s http://localhost:9001/tables)
if echo "$TABLES_RESPONSE" | grep -q "current_prices"; then
    echo "✅ Table 'current_prices' is listed in Pinot!"
else
    echo "⚠️  Warning: Table 'current_prices' not found in table list"
fi

echo ""

# Show table info
echo "📊 Table information:"
curl -s http://localhost:9001/tables/current_prices | jq '.' 2>/dev/null || curl -s http://localhost:9001/tables/current_prices

echo ""
echo "=================================================="
echo "✅ Pinot setup completed!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "1. Ensure Spark Streaming job (Lab 5) is running to produce data"
echo "2. Query data via Pinot Console: http://localhost:9001"
echo "3. Example query:"
echo "   SELECT * FROM current_prices LIMIT 10"
echo ""
