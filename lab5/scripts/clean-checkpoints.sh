#!/bin/bash

echo "=========================================="
echo "🧹 Cleaning Spark Streaming Checkpoints"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CHECKPOINT_PATH="/tmp/spark-checkpoint/moex-current-prices"

# Check if Spark Master is running
if ! docker ps | grep -q "moex-spark-master"; then
    echo -e "${RED}❌ Spark Master is not running${NC}"
    echo "Start it first: ./scripts/start.sh or docker-compose up -d"
    exit 1
fi

echo -e "${YELLOW}Checking checkpoint directory...${NC}"

# Check if checkpoint exists
if docker exec moex-spark-master test -d "$CHECKPOINT_PATH" 2>/dev/null; then
    echo -e "${YELLOW}Found checkpoint directory: $CHECKPOINT_PATH${NC}"

    # Show directory size
    SIZE=$(docker exec moex-spark-master du -sh "$CHECKPOINT_PATH" 2>/dev/null | cut -f1)
    echo "  Size: $SIZE"
    echo ""

    # Ask for confirmation
    read -p "Delete checkpoint directory? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting checkpoint directory...${NC}"
        docker exec moex-spark-master rm -rf "$CHECKPOINT_PATH"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Checkpoint directory deleted successfully${NC}"
        else
            echo -e "${RED}❌ Failed to delete checkpoint directory${NC}"
            exit 1
        fi
    else
        echo "Cancelled."
        exit 0
    fi
else
    echo -e "${GREEN}✅ No checkpoint directory found (already clean)${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Cleanup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Submit new job:  ./scripts/submit-job.sh"
echo "  2. Or restart all:  ./scripts/start.sh"
echo ""
