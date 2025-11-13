#!/bin/bash

# Test script for Lab 6: Data Visualization
# Verifies that all components are working correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "🧪 Testing Lab 6: Data Visualization"
echo "=================================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function for tests
test_service() {
    local name=$1
    local url=$2
    local expected=$3

    echo -n "Testing $name... "

    if curl -s "$url" | grep -q "$expected"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Pinot Controller
echo "1️⃣  Testing Pinot Controller"
test_service "Pinot Controller Health" "http://localhost:9001/health" "OK" || true
echo ""

# Test 2: Pinot Broker
echo "2️⃣  Testing Pinot Broker"
test_service "Pinot Broker Health" "http://localhost:8099/health" "OK" || true
echo ""

# Test 3: Pinot Table exists
echo "3️⃣  Testing Pinot Table"
echo -n "Checking if 'current_prices' table exists... "
if curl -s "http://localhost:9001/tables" | grep -q "current_prices"; then
    echo -e "${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 4: Pinot Query
echo "4️⃣  Testing Pinot Query"
echo -n "Executing query on current_prices... "
QUERY_RESULT=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"sql":"SELECT COUNT(*) FROM current_prices LIMIT 1"}' \
    "http://localhost:8099/query/sql")

if echo "$QUERY_RESULT" | grep -q "resultTable"; then
    echo -e "${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    ROW_COUNT=$(echo "$QUERY_RESULT" | jq -r '.resultTable.rows[0][0]' 2>/dev/null || echo "N/A")
    echo "   📊 Rows in current_prices: $ROW_COUNT"
else
    echo -e "${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 5: Superset Health
echo "5️⃣  Testing Superset"
test_service "Superset Health" "http://localhost:8089/health" "OK" || true
echo ""

# Test 6: Superset DB
echo "6️⃣  Testing Superset Database"
echo -n "Checking Superset PostgreSQL... "
if docker exec superset-db psql -U superset -d superset -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 7: Check Kafka topic
echo "7️⃣  Testing Kafka Topic"
echo -n "Checking moex.current_prices topic... "
if docker exec moex-kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null | grep -q "moex.current_prices"; then
    echo -e "${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))

    # Get message count
    echo -n "   Checking topic messages... "
    MSG_COUNT=$(docker exec moex-kafka kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic moex.current_prices \
        --time -1 2>/dev/null | awk -F':' '{sum += $3} END {print sum}' || echo "0")
    echo "📊 Messages: $MSG_COUNT"
else
    echo -e "${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 8: Docker containers
echo "8️⃣  Testing Docker Containers"
REQUIRED_CONTAINERS=("pinot-controller" "pinot-broker" "pinot-server" "superset" "superset-db")

for container in "${REQUIRED_CONTAINERS[@]}"; do
    echo -n "   Checking $container... "
    if docker ps | grep -q "$container"; then
        echo -e "${GREEN}✅ Running${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ Not Running${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done
echo ""

# Summary
echo "=================================================="
echo "📊 Test Summary"
echo "=================================================="
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! Lab 6 is working correctly.${NC}"
    echo ""
    echo "🎉 You can now:"
    echo "   1. Access Superset: http://localhost:8089 (admin/admin)"
    echo "   2. Access Pinot Console: http://localhost:9001"
    echo "   3. Create visualizations and dashboards"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed. Check the logs:${NC}"
    echo "   docker-compose logs -f"
    exit 1
fi
