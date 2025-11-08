#!/bin/bash

echo "=========================================="
echo "📊 Creating Hive Tables"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Переход в директорию скрипта
cd "$(dirname "$0")/.."

echo -e "${YELLOW}Creating database and tables in Hive...${NC}"
echo ""

# Create SQL script inside container
docker exec hive-server bash -c 'cat > /tmp/create-tables.sql <<EOF
CREATE DATABASE IF NOT EXISTS moex_data;
USE moex_data;

CREATE EXTERNAL TABLE IF NOT EXISTS trades (
    tradeno BIGINT,
    tradetime STRING,
    secid STRING,
    boardid STRING,
    price DOUBLE,
    quantity BIGINT,
    value DOUBLE,
    buysell STRING,
    period STRING,
    tradingsession STRING,
    systime STRING,
    ts_offset BIGINT
)
ROW FORMAT SERDE '"'"'org.apache.hive.hcatalog.data.JsonSerDe'"'"'
STORED AS TEXTFILE
LOCATION '"'"'/user/hive/warehouse/moex_data.db/trades/'"'"';

SHOW TABLES;
DESCRIBE trades;
EOF'

# Execute SQL script
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=false -f /tmp/create-tables.sql

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Tables created successfully${NC}"
else
    echo ""
    echo -e "${RED}❌ Failed to create tables${NC}"
    echo -e "${YELLOW}Make sure HiveServer2 is running: docker ps | grep hive-server${NC}"
    exit 1
fi
echo ""
