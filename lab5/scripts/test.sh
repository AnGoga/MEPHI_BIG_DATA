#!/bin/bash

echo "=========================================="
echo "🔍 Testing Lab 5 Pipeline"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Check Spark Master
echo -e "${YELLOW}1️⃣  Checking Spark Master...${NC}"
if curl -s http://localhost:8083 > /dev/null; then
    echo -e "${GREEN}✅ Spark Master UI accessible${NC}"
else
    echo -e "${RED}❌ Spark Master UI not accessible${NC}"
fi
echo ""

# 2. Check Spark Workers
echo -e "${YELLOW}2️⃣  Checking Spark Workers...${NC}"
WORKERS=$(curl -s http://localhost:8083/json/ 2>/dev/null | grep -o '"aliveworkers":[0-9]*' | grep -o '[0-9]*' || echo "0")
if [ "$WORKERS" -gt 0 ]; then
    echo -e "${GREEN}✅ $WORKERS worker(s) connected${NC}"
else
    echo -e "${RED}❌ No workers connected${NC}"
fi
echo ""

# 3. Check Kafka topic
echo -e "${YELLOW}3️⃣  Checking Kafka topic moex.current_prices...${NC}"
if docker exec moex-kafka kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null | grep -q "moex.current_prices"; then
    echo -e "${GREEN}✅ Topic exists${NC}"
else
    echo -e "${YELLOW}⚠️  Topic not created yet (will be created when Spark job starts)${NC}"
fi
echo ""

# 4. Check messages in topic
echo -e "${YELLOW}4️⃣  Checking messages in moex.current_prices...${NC}"
COUNT=$(docker exec moex-kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic moex.current_prices 2>/dev/null | awk -F':' '{sum += $3} END {print sum}' || echo "0")

if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $COUNT messages${NC}"
    echo ""
    echo -e "${YELLOW}Sample messages:${NC}"
    docker exec moex-kafka kafka-console-consumer \
      --bootstrap-server localhost:9092 \
      --topic moex.current_prices \
      --max-messages 3 \
      --timeout-ms 5000 2>/dev/null || true
else
    echo -e "${YELLOW}⚠️  No messages yet. Make sure:${NC}"
    echo "   1. MOEX collector is running (cd moex-collector && ./gradlew bootRun)"
    echo "   2. Spark job is submitted (./scripts/submit-job.sh)"
    echo "   3. Data is flowing from moex.trades"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Test Complete!${NC}"
echo "=========================================="
echo ""
echo "🌐 Access Points:"
echo "  • Spark Master UI: http://localhost:8083"
echo "  • Kafka UI:        http://localhost:8080 → Topics → moex.current_prices"
echo ""
