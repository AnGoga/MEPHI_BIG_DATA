#!/bin/bash

echo "=========================================="
echo "🛑 Stopping Lab 3 Infrastructure"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Переход в директорию скрипта
cd "$(dirname "$0")/.."

echo -e "${YELLOW}📋 Stopping all containers...${NC}"
docker-compose down

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All containers stopped successfully${NC}"
else
    echo -e "${RED}❌ Failed to stop some containers${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}💡 Tip: To remove all data and start fresh, run:${NC}"
echo "   docker-compose down -v"
echo ""
echo -e "${GREEN}✅ Lab 3 infrastructure stopped${NC}"
echo ""
