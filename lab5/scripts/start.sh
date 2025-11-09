#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting Lab 5: Spark Streaming"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# 1. Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker and Docker Compose found${NC}"
echo ""

# 2. Check moex-network
echo -e "${YELLOW}📋 Checking moex-network...${NC}"
if ! docker network inspect moex-network >/dev/null 2>&1; then
    echo -e "${RED}❌ Network 'moex-network' not found${NC}"
    echo -e "${YELLOW}Please start Kafka first:${NC}"
    echo "   cd docker/kafka && docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ Network 'moex-network' exists${NC}"
echo ""

# 3. Start Docker Compose
echo -e "${YELLOW}📋 Starting Spark cluster...${NC}"
docker-compose up -d

echo ""
echo -e "${YELLOW}⏳ Waiting for services to start (20 seconds)...${NC}"
sleep 20

# 4. Check service health
echo ""
echo -e "${YELLOW}📋 Checking service health...${NC}"

if docker ps | grep -q "moex-spark-master"; then
    echo -e "${GREEN}✅ Spark Master is running${NC}"
else
    echo -e "${RED}❌ Spark Master failed to start${NC}"
fi

if docker ps | grep -q "moex-spark-worker-1"; then
    echo -e "${GREEN}✅ Spark Worker 1 is running${NC}"
else
    echo -e "${RED}❌ Spark Worker 1 failed to start${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Lab 5 Spark Cluster is Ready!${NC}"
echo "=========================================="
echo ""
echo "🌐 Access Points:"
echo "  • Spark Master UI:  http://localhost:8083"
echo "  • Spark Master RPC: spark://localhost:7077"
echo ""
echo "📝 Next Steps:"
echo "  1. Build application:    ./scripts/build-app.sh"
echo "  2. Submit Spark job:     ./scripts/submit-job.sh"
echo "  3. View results:         ./scripts/view-current-prices.sh"
echo "  4. Test pipeline:        ./scripts/test.sh"
echo ""
