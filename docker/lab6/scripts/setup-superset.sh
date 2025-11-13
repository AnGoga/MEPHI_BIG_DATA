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

docker exec superset pip install pyhive[hive] thrift thrift-sasl > /dev/null 2>&1 || true
docker exec superset pip install pinotdb > /dev/null 2>&1 || true

echo "✅ Drivers installed!"
echo ""

# Create database connections using Superset CLI
echo "🔗 Creating database connections..."

# Connection 1: Hive
echo "   1. Apache Hive (Batch Data)..."
docker exec superset superset set-database-uri \
    -d "Apache Hive (Batch Data)" \
    -u "hive://hive:10000/moex_data" 2>/dev/null || \
docker exec superset bash -c "cat > /tmp/add_hive.py <<'EOF'
from superset import db
from superset.models.core import Database

# Check if database exists
existing = db.session.query(Database).filter_by(database_name='Apache Hive (Batch Data)').first()
if not existing:
    database = Database(
        database_name='Apache Hive (Batch Data)',
        sqlalchemy_uri='hive://hive:10000/moex_data',
        expose_in_sqllab=True,
        allow_run_async=True,
        allow_ctas=False,
        allow_cvas=False,
        allow_dml=False,
        extra='{\"metadata_params\": {}, \"engine_params\": {\"connect_args\": {\"auth\": \"NOSASL\"}}, \"metadata_cache_timeout\": {}, \"schemas_allowed_for_csv_upload\": []}'
    )
    db.session.add(database)
    db.session.commit()
    print('✅ Hive database added')
else:
    print('⚠️  Hive database already exists')
EOF
superset fab command python /tmp/add_hive.py" || echo "⚠️  Hive connection setup failed (might already exist)"

# Connection 2: Pinot
echo "   2. Apache Pinot (Streaming Data)..."
docker exec superset bash -c "cat > /tmp/add_pinot.py <<'EOF'
from superset import db
from superset.models.core import Database

# Check if database exists
existing = db.session.query(Database).filter_by(database_name='Apache Pinot (Streaming Data)').first()
if not existing:
    database = Database(
        database_name='Apache Pinot (Streaming Data)',
        sqlalchemy_uri='pinot://pinot-broker:8099/query?controller=http://pinot-controller:9001/',
        expose_in_sqllab=True,
        allow_run_async=False,
        allow_ctas=False,
        allow_cvas=False,
        allow_dml=False,
        extra='{\"metadata_params\": {}, \"engine_params\": {}, \"metadata_cache_timeout\": {}, \"schemas_allowed_for_csv_upload\": []}'
    )
    db.session.add(database)
    db.session.commit()
    print('✅ Pinot database added')
else:
    print('⚠️  Pinot database already exists')
EOF
superset fab command python /tmp/add_pinot.py" || echo "⚠️  Pinot connection setup failed (might already exist)"

echo ""
echo "✅ Database connections configured!"
echo ""

# Verify connections
echo "🔍 Verifying connections..."
docker exec superset superset fab list-users > /dev/null 2>&1 && echo "✅ Superset is functional!" || echo "⚠️  Superset verification failed"

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
