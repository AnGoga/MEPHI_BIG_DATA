#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting YARN Cluster"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# Check Docker
echo -e "${YELLOW}Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker found${NC}"
echo ""

# Check moex-network
echo -e "${YELLOW}Checking moex-network...${NC}"
if ! docker network inspect moex-network >/dev/null 2>&1; then
    echo -e "${RED}❌ Network 'moex-network' not found${NC}"
    echo -e "${YELLOW}Please start Lab 3 infrastructure first (HDFS + Hive)${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Network 'moex-network' exists${NC}"
echo ""

# Check NameNode is running
echo -e "${YELLOW}Checking HDFS NameNode...${NC}"
if ! docker ps | grep -q hadoop-namenode; then
    echo -e "${RED}❌ HDFS NameNode is not running${NC}"
    echo -e "${YELLOW}Please start Lab 3 infrastructure first:${NC}"
    echo "   cd docker/lab3 && ./scripts/start.sh"
    exit 1
fi
echo -e "${GREEN}✅ HDFS NameNode is running${NC}"
echo ""

# Start YARN
echo -e "${YELLOW}Starting YARN services...${NC}"
docker-compose up -d

echo ""
echo -e "${YELLOW}Waiting for YARN to start (15 seconds)...${NC}"
sleep 15

# Check services
if docker ps | grep -q hadoop-resourcemanager; then
    echo -e "${GREEN}✅ ResourceManager is running${NC}"
else
    echo -e "${RED}❌ ResourceManager failed to start${NC}"
    exit 1
fi

if docker ps | grep -q hadoop-nodemanager; then
    echo -e "${GREEN}✅ NodeManager is running${NC}"
else
    echo -e "${RED}❌ NodeManager failed to start${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ YARN Cluster is Running!${NC}"
echo "=========================================="
echo ""
echo "🌐 Web UIs:"
echo "  • ResourceManager:  http://localhost:8088"
echo "  • NodeManager:      http://localhost:8042"
echo "  • History Server:   http://localhost:8188"
echo ""
