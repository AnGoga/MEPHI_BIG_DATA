#!/bin/bash
set -e

echo "📤 Submitting Spark Streaming Job"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

JAR_PATH="spark-streaming/build/libs/moex-streaming-1.0.0-all.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo -e "${RED}❌ JAR not found: $JAR_PATH${NC}"
    echo "Build first: ./scripts/build-app.sh"
    exit 1
fi

echo -e "${GREEN}✅ JAR found: $JAR_PATH${NC}"
echo ""

# Check that Spark Master is running
if ! docker ps | grep -q "moex-spark-master"; then
    echo -e "${RED}❌ Spark Master is not running${NC}"
    echo "Start first: ./scripts/start.sh"
    exit 1
fi

echo -e "${YELLOW}Submitting job to Spark Master...${NC}"

# JAR is already available via volume mount at /opt/spark-apps/
docker exec moex-spark-master /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --deploy-mode client \
  --class ru.mephi.moex.streaming.MoexCurrentPriceCalculator \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.3 \
  --conf spark.executor.memory=1g \
  --conf spark.executor.cores=1 \
  --conf spark.sql.shuffle.partitions=3 \
  /opt/spark-apps/moex-streaming-1.0.0-all.jar

echo ""
echo -e "${GREEN}✅ Job submitted!${NC}"
echo "Monitor at: http://localhost:8083"
