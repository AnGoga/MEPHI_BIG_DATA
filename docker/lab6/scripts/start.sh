#!/bin/bash

# Start script for Lab 6: Data Visualization
# This script starts all services and configures Pinot and Superset

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "🚀 Starting Lab 6: Data Visualization"
echo "=================================================="
echo ""
echo "This will start:"
echo "  - Apache Pinot (Controller, Broker, Server)"
echo "  - Apache Superset"
echo "  - PostgreSQL (for Superset metadata)"
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
    cd "$PROJECT_ROOT/../kafka" && docker-compose up -d
    sleep 10
    cd "$PROJECT_ROOT"
fi
echo "✅ Kafka is running"

echo ""

# Start Lab 6 services
echo "🚀 Starting Lab 6 services..."
cd "$PROJECT_ROOT"
docker-compose up -d

echo ""
echo "⏳ Waiting for services to initialize..."
echo "   This may take 2-3 minutes..."
sleep 30

echo ""

# Setup Pinot
echo "📊 Setting up Apache Pinot..."
bash "$SCRIPT_DIR/setup-pinot.sh"

echo ""

# Setup Superset
echo "🎨 Setting up Apache Superset..."
bash "$SCRIPT_DIR/setup-superset.sh"

echo ""
echo "=================================================="
echo "✅ Lab 6 started successfully!"
echo "=================================================="
echo ""
echo "🌐 Web Interfaces:"
echo "   Superset:        http://localhost:8089 (admin / admin)"
echo "   Pinot Console:   http://localhost:9001"
echo "   Kafka UI:        http://localhost:8080"
echo ""
echo "📊 Data Sources:"
echo "   Hive (Batch):    hive://hive:10000/moex_data"
echo "   Pinot (Stream):  current_prices table"
echo ""
echo "📝 Next Steps:"
echo "   1. Open Superset: http://localhost:8089"
echo "   2. Login with admin / admin"
echo "   3. Go to SQL Lab to explore data"
echo "   4. Create charts and dashboards"
echo ""
echo "💡 Tips:"
echo "   - Ensure Lab 5 (Spark Streaming) is running for real-time data"
echo "   - Use 'docker-compose logs -f [service]' to view logs"
echo "   - Use './scripts/test.sh' to verify the setup"
echo ""
