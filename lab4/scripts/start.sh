#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Lab 4: MapReduce - All-in-One"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# Step 1: Build JAR
#echo -e "${YELLOW}Step 1/3: Building MapReduce JAR...${NC}"
#./scripts/build-job.sh

# Step 2: Start YARN
echo -e "${YELLOW}Step 2/3: Starting YARN cluster...${NC}"
./scripts/start-yarn.sh

# Step 3: Submit Job
echo -e "${YELLOW}Step 3/3: Submitting MapReduce job...${NC}"
./scripts/submit-job.sh

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Lab 4 Complete!${NC}"
echo "=========================================="
echo ""
echo "📊 View Results:"
echo "  ./scripts/view-results.sh"
echo ""
echo "🌐 YARN Web UI:"
echo "  http://localhost:8088"
echo ""
echo "🛑 Stop YARN:"
echo "  ./scripts/stop-yarn.sh"
echo ""
