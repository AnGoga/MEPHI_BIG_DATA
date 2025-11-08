#!/bin/bash

echo "=========================================="
echo "🔍 Testing Lab 3 Pipeline"
echo "  Kafka → NiFi → Hive → HDFS"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переход в директорию скрипта
cd "$(dirname "$0")/.."

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  1️⃣  Checking HDFS Health${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📁 HDFS Directory Structure:${NC}"
docker exec hadoop-namenode hadoop fs -ls -R /user/hive/warehouse/moex_data.db/ 2>/dev/null || {
    echo -e "${RED}❌ No data directory found in HDFS${NC}"
    echo -e "${YELLOW}   This is normal if NiFi hasn't written any data yet${NC}"
}
echo ""

echo -e "${YELLOW}📊 File count in trades directory:${NC}"
FILE_COUNT=$(docker exec hadoop-namenode hadoop fs -ls /user/hive/warehouse/moex_data.db/trades/ 2>/dev/null | grep -v "Found" | wc -l)
if [ "$FILE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Found $FILE_COUNT file(s) in HDFS${NC}"
    echo ""
    echo -e "${YELLOW}Latest files:${NC}"
    docker exec hadoop-namenode hadoop fs -ls -t /user/hive/warehouse/moex_data.db/trades/ 2>/dev/null | head -5
else
    echo -e "${YELLOW}⚠️  No files found yet${NC}"
    echo -e "   Make sure NiFi dataflow is running and MOEX collector is sending data to Kafka"
fi
echo ""

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  2️⃣  Checking Hive Tables${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📋 Available tables in moex_data database:${NC}"
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=true -e "
USE moex_data;
SHOW TABLES;
"
echo ""

echo -e "${YELLOW}📊 Table schema:${NC}"
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=true -e "
USE moex_data;
DESCRIBE trades;
"
echo ""

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  3️⃣  Checking Data in Hive${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}📈 Total number of trades:${NC}"
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=true -e "
USE moex_data;
SELECT COUNT(*) as total_trades FROM trades;
"
echo ""

echo -e "${YELLOW}📊 Trades by security (top 10):${NC}"
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=true -e "
USE moex_data;
SELECT secid, COUNT(*) as trade_count
FROM trades
GROUP BY secid
ORDER BY trade_count DESC
LIMIT 10;
" 2>/dev/null || echo -e "${YELLOW}No data available yet${NC}"
echo ""

echo -e "${YELLOW}🕐 Latest trades (last 10):${NC}"
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=true -e "
USE moex_data;
SELECT tradeno, tradetime, secid, price, quantity, buysell
FROM trades
ORDER BY tradetime DESC
LIMIT 10;
" 2>/dev/null || echo -e "${YELLOW}No data available yet${NC}"
echo ""

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  4️⃣  Service Status Summary${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}🐳 Docker Container Status:${NC}"
docker-compose ps
echo ""

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  5️⃣  Access Points${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo "🌐 Web Interfaces:"
echo "  • Hadoop NameNode:  http://localhost:9870"
echo "  • NiFi UI:          http://localhost:8082/nifi"
echo ""
echo "📊 Database Connection:"
echo "  • JDBC URL:         jdbc:hive2://localhost:10000"
echo "  • Username:         root"
echo "  • Database:         moex_data"
echo ""

echo "=========================================="
echo -e "${GREEN}✅ Test Complete!${NC}"
echo "=========================================="
echo ""
