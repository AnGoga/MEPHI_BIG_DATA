#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting Lab 5: Spark Streaming"
echo "  All-in-one: Cluster + Build + Submit"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# 1. Check Docker
echo -e "${YELLOW}📋 Step 1/5: Checking prerequisites...${NC}"
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
echo -e "${YELLOW}📋 Step 2/5: Checking moex-network...${NC}"
if ! docker network inspect moex-network >/dev/null 2>&1; then
    echo -e "${RED}❌ Network 'moex-network' not found${NC}"
    echo -e "${YELLOW}Please start Kafka first:${NC}"
    echo "   cd docker/kafka && docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ Network 'moex-network' exists${NC}"
echo ""

# 3. Start Docker Compose (Spark cluster)
echo -e "${YELLOW}📋 Step 3/5: Starting Spark cluster...${NC}"
docker-compose up -d

echo -e "${YELLOW}⏳ Waiting for Spark services to start (20 seconds)...${NC}"
sleep 20

if docker ps | grep -q "moex-spark-master"; then
    echo -e "${GREEN}✅ Spark Master is running${NC}"
else
    echo -e "${RED}❌ Spark Master failed to start${NC}"
    exit 1
fi

if docker ps | grep -q "moex-spark-worker-1"; then
    echo -e "${GREEN}✅ Spark Worker 1 is running${NC}"
else
    echo -e "${RED}❌ Spark Worker 1 failed to start${NC}"
    exit 1
fi
echo ""

# 4. Build Kotlin application
echo -e "${YELLOW}📋 Step 4/5: Building Spark Streaming application...${NC}"
cd spark-streaming

if [ ! -f "gradlew" ]; then
    echo -e "${RED}❌ gradlew not found${NC}"
    exit 1
fi

echo "📦 Running ./gradlew clean shadowJar..."
./gradlew clean shadowJar

JAR_PATH="build/libs/moex-streaming-1.0.0-all.jar"

if [ -f "$JAR_PATH" ]; then
    echo -e "${GREEN}✅ JAR built successfully: $JAR_PATH${NC}"
    ls -lh "$JAR_PATH"
else
    echo -e "${RED}❌ JAR build failed${NC}"
    exit 1
fi

cd ..
echo ""

# 5. Submit Spark job
echo -e "${YELLOW}📋 Step 5/5: Submitting Spark Streaming job...${NC}"

if ! docker ps | grep -q "moex-spark-master"; then
    echo -e "${RED}❌ Spark Master is not running${NC}"
    exit 1
fi

echo "Submitting job to Spark Master..."

# Run spark-submit in background
docker exec -d moex-spark-master spark-submit \
  --master spark://spark-master:7077 \
  --deploy-mode client \
  --class ru.mephi.moex.streaming.MoexCurrentPriceCalculator \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
  --conf spark.executor.memory=1g \
  --conf spark.executor.cores=1 \
  --conf spark.sql.shuffle.partitions=3 \
  /opt/spark-apps/moex-streaming-1.0.0-all.jar

echo -e "${GREEN}✅ Spark job submitted (running in background)${NC}"
echo ""

echo "=========================================="
echo -e "${GREEN}✅ Lab 5 is Running!${NC}"
echo "=========================================="
echo ""
echo "🌐 Access Points:"
echo "  • Spark Master UI:  http://localhost:8083"
echo "  • Spark Job UI:     http://localhost:4040 (when job starts)"
echo "  • Kafka UI:         http://localhost:8080"
echo ""
echo "📊 View Results:"
echo "  ./scripts/view-current-prices.sh"
echo ""
echo "🧪 Test Pipeline:"
echo "  ./scripts/test.sh"
echo ""
echo "🛑 Stop Everything:"
echo "  ./scripts/stop.sh"
echo ""
