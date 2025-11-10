#!/bin/bash
set -e

echo "=========================================="
echo "📤 Submitting MapReduce Job"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

JAR_PATH="mapreduce-job/build/libs/moex-mapreduce-1.0.0-all.jar"

# Check JAR exists
if [ ! -f "$JAR_PATH" ]; then
    echo -e "${RED}❌ JAR not found: $JAR_PATH${NC}"
    echo "Build first: ./scripts/build-job.sh"
    exit 1
fi

echo -e "${GREEN}✅ JAR found: $JAR_PATH${NC}"
echo ""

# Check ResourceManager is running
if ! docker ps | grep -q hadoop-resourcemanager; then
    echo -e "${RED}❌ ResourceManager is not running${NC}"
    echo "Start YARN first: ./scripts/start-yarn.sh"
    exit 1
fi

echo -e "${GREEN}✅ ResourceManager is running${NC}"
echo ""

# Define paths
INPUT_PATH="/user/hive/warehouse/moex_data.db/trades"
OUTPUT_PATH="/user/hive/warehouse/moex_data.db/trade_volumes_hourly"

echo -e "${YELLOW}Job Configuration:${NC}"
echo "  Input:  $INPUT_PATH"
echo "  Output: $OUTPUT_PATH"
echo ""

# Remove output directory if exists
echo -e "${YELLOW}Cleaning output directory...${NC}"
docker exec hadoop-namenode hadoop fs -rm -r -f "$OUTPUT_PATH" || true
echo ""

# Submit job
echo -e "${YELLOW}Submitting MapReduce job to YARN...${NC}"
echo ""

# Note: Main-Class is already in JAR manifest, so we don't specify it
docker exec hadoop-resourcemanager hadoop jar \
  /opt/mapreduce-apps/moex-mapreduce-1.0.0-all.jar \
  "$INPUT_PATH" \
  "$OUTPUT_PATH"

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Job Completed!${NC}"
echo "=========================================="
echo ""
echo "📊 View Results:"
echo "  hadoop fs -cat $OUTPUT_PATH/part-* | head -20"
echo ""
echo "Or run: ./scripts/view-results.sh"
echo ""
