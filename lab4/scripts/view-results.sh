#!/bin/bash

echo "=========================================="
echo "📊 Viewing MapReduce Results"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

OUTPUT_PATH="/user/hive/warehouse/moex_data.db/trade_volumes_hourly"

# Check if output exists
if ! docker exec hadoop-namenode hadoop fs -test -d "$OUTPUT_PATH" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Output directory not found: $OUTPUT_PATH${NC}"
    echo "Run the job first: ./scripts/submit-job.sh"
    exit 1
fi

echo -e "${GREEN}Output directory found!${NC}"
echo ""

# List output files
echo -e "${YELLOW}Output files:${NC}"
docker exec hadoop-namenode hadoop fs -ls "$OUTPUT_PATH"
echo ""

# Show top 20 results
echo -e "${YELLOW}Top 20 results:${NC}"
echo ""
docker exec hadoop-namenode hadoop fs -cat "$OUTPUT_PATH/part-*" | head -20
echo ""

# Show statistics
echo -e "${YELLOW}Statistics:${NC}"
TOTAL_LINES=$(docker exec hadoop-namenode hadoop fs -cat "$OUTPUT_PATH/part-*" | wc -l)
echo "  Total records: $TOTAL_LINES"
echo ""
