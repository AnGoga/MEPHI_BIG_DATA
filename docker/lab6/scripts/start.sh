#!/bin/bash

# Start script for Lab 6: Data Visualization
# This script starts all services and configures Pinot and Superset AUTOMATICALLY

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "🚀 Starting Lab 6: Data Visualization"
echo "=================================================="
echo ""
echo "This will:"
echo "  1. Start all services (Pinot, Superset, PostgreSQL, Zookeeper)"
echo "  2. Wait for services to be ready"
echo "  3. Initialize Superset database and admin user"
echo "  4. Setup Pinot table for current_prices"
echo "  5. Configure Superset database connections"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if moex-network exists
if ! docker network inspect moex-network > /dev/null 2>&1; then
    echo "❌ Error: moex-network does not exist"
    echo "   Please run Lab 1-2 first:"
    echo "   cd docker/kafka && docker-compose up -d"
    exit 1
fi
echo "✅ moex-network exists"

# Check if Kafka is running
if ! docker ps | grep -q moex-kafka; then
    echo "⚠️  Warning: Kafka is not running"
    echo "   Starting Kafka..."
    cd "$PROJECT_ROOT/../kafka" && docker compose up -d
    sleep 10
    cd "$PROJECT_ROOT"
fi
echo "✅ Kafka is running"

echo ""

# Start Lab 6 services
echo "=========================================="
echo "📦 Step 1/5: Starting Docker containers"
echo "=========================================="
cd "$PROJECT_ROOT"
docker compose up -d

echo ""
echo "⏳ Waiting for services to start..."
echo "   This may take 1-2 minutes..."
sleep 45

echo ""

# Check services status
echo "=========================================="
echo "🔍 Checking services status"
echo "=========================================="

SERVICES=("pinot-zookeeper" "pinot-controller" "pinot-broker" "pinot-server" "superset-db" "superset")
ALL_RUNNING=true

for service in "${SERVICES[@]}"; do
    if docker ps | grep -q "$service"; then
        echo "✅ $service is running"
    else
        echo "❌ $service is NOT running"
        ALL_RUNNING=false
    fi
done

if [ "$ALL_RUNNING" = false ]; then
    echo ""
    echo "⚠️  Some services failed to start. Check logs:"
    echo "   docker compose logs -f"
    exit 1
fi

echo ""

# Initialize Superset
echo "=========================================="
echo "🎨 Step 2/5: Initializing Superset"
echo "=========================================="

echo "⏳ Waiting for Superset to be fully ready..."
sleep 15

echo "   - Upgrading Superset database..."
docker exec superset superset db upgrade > /dev/null 2>&1 || echo "   (db upgrade may have already run)"

echo "   - Creating admin user..."
docker exec superset superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@superset.com \
    --password admin 2>&1 | grep -v "already exists" || echo "   (admin user may already exist)"

echo "   - Initializing Superset..."
docker exec superset superset init > /dev/null 2>&1 || echo "   (init may have already run)"

echo "✅ Superset initialized!"

echo ""

# Setup Pinot
echo "=========================================="
echo "📊 Step 3/5: Setting up Apache Pinot"
echo "=========================================="

# Wait for Pinot Controller
echo "⏳ Waiting for Pinot Controller..."
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
        echo "   Check logs: docker logs pinot-controller"
        exit 1
    fi

    echo "   Waiting... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo ""
echo "   - Creating Pinot schema: current_prices"
SCHEMA_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @"$PROJECT_ROOT/pinot-configs/current_prices_schema.json" \
    http://localhost:9001/schemas)

if echo "$SCHEMA_RESPONSE" | grep -q "error"; then
    if echo "$SCHEMA_RESPONSE" | grep -q "already exists"; then
        echo "   ℹ️  Schema already exists (OK)"
    else
        echo "   ⚠️  Error creating schema: $SCHEMA_RESPONSE"
    fi
else
    echo "   ✅ Schema created!"
fi

echo ""
echo "   - Creating Pinot table: current_prices (REALTIME)"
TABLE_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d @"$PROJECT_ROOT/pinot-configs/current_prices_table.json" \
    http://localhost:9001/tables)

if echo "$TABLE_RESPONSE" | grep -q "error"; then
    if echo "$TABLE_RESPONSE" | grep -q "already exists"; then
        echo "   ℹ️  Table already exists (OK)"
    else
        echo "   ⚠️  Error creating table: $TABLE_RESPONSE"
    fi
else
    echo "   ✅ Table created!"
fi

echo ""
echo "✅ Pinot setup completed!"

echo ""

# Setup Superset connections
echo "=========================================="
echo "🔗 Step 4/5: Configuring Superset connections"
echo "=========================================="

echo "   - Installing database drivers..."
docker exec superset pip install pyhive[hive] thrift thrift-sasl pinotdb > /dev/null 2>&1 || echo "   (drivers may already be installed)"

echo "   - Creating Hive connection..."
docker exec superset bash -c "cat > /tmp/add_hive.py <<'EOF'
from superset import db
from superset.models.core import Database

existing = db.session.query(Database).filter_by(database_name='Apache Hive (Batch Data)').first()
if not existing:
    database = Database(
        database_name='Apache Hive (Batch Data)',
        sqlalchemy_uri='hive://hive:10000/moex_data',
        expose_in_sqllab=True,
        allow_run_async=True,
        allow_ctas=False,
        allow_cvas=False,
        allow_dml=False
    )
    db.session.add(database)
    db.session.commit()
    print('✅ Hive connection added')
else:
    print('ℹ️  Hive connection already exists')
EOF
superset fab command python /tmp/add_hive.py" 2>/dev/null || echo "   ℹ️  Hive connection setup (may already exist)"

echo "   - Creating Pinot connection..."
docker exec superset bash -c "cat > /tmp/add_pinot.py <<'EOF'
from superset import db
from superset.models.core import Database

existing = db.session.query(Database).filter_by(database_name='Apache Pinot (Streaming Data)').first()
if not existing:
    database = Database(
        database_name='Apache Pinot (Streaming Data)',
        sqlalchemy_uri='pinot://pinot-broker:8099/query?controller=http://pinot-controller:9001/',
        expose_in_sqllab=True,
        allow_run_async=False,
        allow_ctas=False,
        allow_cvas=False,
        allow_dml=False
    )
    db.session.add(database)
    db.session.commit()
    print('✅ Pinot connection added')
else:
    print('ℹ️  Pinot connection already exists')
EOF
superset fab command python /tmp/add_pinot.py" 2>/dev/null || echo "   ℹ️  Pinot connection setup (may already exist)"

echo ""
echo "✅ Superset connections configured!"

echo ""

# Final status check
echo "=========================================="
echo "🧪 Step 5/5: Final health check"
echo "=========================================="

HEALTHY=true

# Check Pinot
if curl -s http://localhost:9001/health | grep -q "OK"; then
    echo "✅ Pinot Controller: healthy"
else
    echo "⚠️  Pinot Controller: not responding"
    HEALTHY=false
fi

# Check Superset
if curl -s http://localhost:8089/health > /dev/null 2>&1; then
    echo "✅ Superset: healthy"
else
    echo "⚠️  Superset: not responding"
    HEALTHY=false
fi

# Check Pinot table
TABLES=$(curl -s http://localhost:9001/tables 2>/dev/null)
if echo "$TABLES" | grep -q "current_prices"; then
    echo "✅ Pinot table 'current_prices': exists"
else
    echo "⚠️  Pinot table 'current_prices': not found"
    HEALTHY=false
fi

echo ""

if [ "$HEALTHY" = true ]; then
    echo "=================================================="
    echo "✅ Lab 6 started successfully!"
    echo "=================================================="
else
    echo "=================================================="
    echo "⚠️  Lab 6 started with some issues"
    echo "=================================================="
    echo ""
    echo "Check logs for details:"
    echo "   docker compose logs -f"
fi

echo ""
echo "🌐 Web Interfaces:"
echo "   Superset:        http://localhost:8089 (admin / admin)"
echo "   Pinot Console:   http://localhost:9001"
echo "   Kafka UI:        http://localhost:8080"
echo ""
echo "📊 Data Sources:"
echo "   Hive (Batch):    moex_data.trades, moex_data.trade_volumes_hourly"
echo "   Pinot (Stream):  current_prices table"
echo ""
echo "📝 Next Steps:"
echo "   1. Open Superset: http://localhost:8089"
echo "   2. Login with admin / admin"
echo "   3. Go to SQL Lab → select database"
echo "   4. Create charts and dashboards"
echo ""
echo "💡 Tips:"
echo "   - Ensure Lab 5 (Spark) is running for real-time data"
echo "   - Use './scripts/test.sh' to verify everything"
echo "   - Use 'docker compose logs [service]' for debugging"
echo ""
