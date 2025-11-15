#!/bin/bash

echo "📤 Submitting Spark Streaming Job"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# Parse arguments
CLEAN_CHECKPOINT=false
RUN_IN_BACKGROUND=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_CHECKPOINT=true
            shift
            ;;
        --background|-d)
            RUN_IN_BACKGROUND=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--clean] [--background|-d]"
            echo "  --clean       Clean checkpoint directory before submit"
            echo "  --background  Run job in background"
            exit 1
            ;;
    esac
done

JAR_PATH="spark-streaming/build/libs/moex-streaming-1.0.0-all.jar"

if [ ! -f "$JAR_PATH" ]; then
    echo -e "${RED}❌ FAT JAR not found: $JAR_PATH${NC}"
    echo "Build shadowJar first: ./gradlew clean shadowJar"
    echo ""
    echo "Available JARs:"
    ls -lh spark-streaming/build/libs/*.jar 2>/dev/null || echo "  (none)"
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

# Clean checkpoint if requested
if [ "$CLEAN_CHECKPOINT" = true ]; then
    echo -e "${YELLOW}🧹 Cleaning checkpoint directory...${NC}"
    docker exec moex-spark-master rm -rf /tmp/spark-checkpoint/moex-current-prices 2>/dev/null || true
    echo -e "${GREEN}✅ Checkpoint cleaned${NC}"
    echo ""
fi

echo -e "${YELLOW}Submitting job to Spark Master...${NC}"

# JAR is already available via volume mount at /opt/spark-apps/
# All dependencies (including Kafka connector) are packaged in the fat JAR
if [ "$RUN_IN_BACKGROUND" = true ]; then
    docker exec -d moex-spark-master /opt/spark/bin/spark-submit \
      --master spark://spark-master:7077 \
      --deploy-mode client \
      --class ru.mephi.moex.streaming.MoexCurrentPriceCalculator \
      --conf spark.executor.memory=1g \
      --conf spark.executor.cores=1 \
      --conf spark.sql.shuffle.partitions=3 \
      /opt/spark-apps/moex-streaming-1.0.0-all.jar

    echo ""
    echo -e "${GREEN}✅ Job submitted in background!${NC}"
else
    docker exec moex-spark-master /opt/spark/bin/spark-submit \
      --master spark://spark-master:7077 \
      --deploy-mode client \
      --class ru.mephi.moex.streaming.MoexCurrentPriceCalculator \
      --conf spark.executor.memory=1g \
      --conf spark.executor.cores=1 \
      --conf spark.sql.shuffle.partitions=3 \
      /opt/spark-apps/moex-streaming-1.0.0-all.jar

    echo ""
    echo -e "${GREEN}✅ Job completed!${NC}"
fi

echo "Monitor at: http://localhost:8083"
