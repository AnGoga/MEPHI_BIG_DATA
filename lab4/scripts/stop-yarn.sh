#!/bin/bash

echo "=========================================="
echo "🛑 Stopping YARN Cluster"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
NC='\033[0m'

cd "$(dirname "$0")/.."

docker-compose down

echo ""
echo -e "${GREEN}✅ YARN Cluster stopped${NC}"
echo ""
