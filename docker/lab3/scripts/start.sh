#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting Lab 3 Infrastructure"
echo "  HDFS + Hive + NiFi for MOEX Data"
echo "=========================================="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Переход в директорию скрипта
cd "$(dirname "$0")/.."

echo -e "${YELLOW}📋 Step 1: Checking prerequisites${NC}"
# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

# Проверка Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker and Docker Compose are installed${NC}"
echo ""

echo -e "${YELLOW}📋 Step 2: Creating Docker network${NC}"
# Создать сеть если не существует
if ! docker network inspect moex-network >/dev/null 2>&1; then
    docker network create moex-network
    echo -e "${GREEN}✅ Network 'moex-network' created${NC}"
else
    echo -e "${GREEN}✅ Network 'moex-network' already exists${NC}"
fi
echo ""

echo -e "${YELLOW}📋 Step 3: Starting Docker containers${NC}"
docker-compose up -d
echo ""

echo -e "${YELLOW}⏳ Step 4: Waiting for services to initialize (60 seconds)...${NC}"
echo "   This may take a while on first run (downloading images)"
sleep 60
echo ""

echo -e "${YELLOW}📋 Step 5: Checking service health${NC}"
# Проверка статуса контейнеров
if docker ps | grep -q "hadoop-namenode"; then
    echo -e "${GREEN}✅ Hadoop NameNode is running${NC}"
else
    echo -e "${RED}❌ Hadoop NameNode failed to start${NC}"
fi

if docker ps | grep -q "hadoop-datanode"; then
    echo -e "${GREEN}✅ Hadoop DataNode is running${NC}"
else
    echo -e "${RED}❌ Hadoop DataNode failed to start${NC}"
fi

if docker ps | grep -q "hive-metastore-db"; then
    echo -e "${GREEN}✅ PostgreSQL (Metastore) is running${NC}"
else
    echo -e "${RED}❌ PostgreSQL failed to start${NC}"
fi

if docker ps | grep -q "hive-server"; then
    echo -e "${GREEN}✅ Hive Server is running${NC}"
else
    echo -e "${RED}❌ Hive Server failed to start${NC}"
fi

if docker ps | grep -q "nifi"; then
    echo -e "${GREEN}✅ NiFi is running${NC}"
else
    echo -e "${RED}❌ NiFi failed to start${NC}"
fi
echo ""

echo -e "${YELLOW}📋 Step 6: Initializing HDFS directories${NC}"
# Даем HDFS время на полную инициализацию
sleep 10

# Создание директорий в HDFS
docker exec hadoop-namenode hadoop fs -mkdir -p /user/hive/warehouse || true
docker exec hadoop-namenode hadoop fs -chmod g+w /user/hive/warehouse || true
docker exec hadoop-namenode hadoop fs -mkdir -p /tmp || true
docker exec hadoop-namenode hadoop fs -chmod 777 /tmp || true
docker exec hadoop-namenode hadoop fs -mkdir -p /user/hive/warehouse/moex_data.db/trades || true
docker exec hadoop-namenode hadoop fs -chmod 777 /user/hive/warehouse/moex_data.db/trades || true

echo -e "${GREEN}✅ HDFS directories created${NC}"
echo ""

echo -e "${YELLOW}📋 Step 7: Initializing Hive Metastore schema${NC}"
# Даем Hive время на подключение к PostgreSQL
sleep 15

# Инициализация схемы Metastore (только при первом запуске)
docker exec hive-server /opt/hive/bin/schematool -dbType postgres -initSchema 2>&1 | grep -v "already exists" || {
    echo -e "${GREEN}✅ Hive Metastore schema initialized (or already exists)${NC}"
}
echo ""

echo -e "${YELLOW}📋 Step 8: Creating Hive database and tables${NC}"
# Даем HiveServer2 время на запуск
sleep 20

# Создание базы данных и таблиц
docker exec hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root --silent=true <<EOF
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
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/moex_data.db/trades/';

SHOW TABLES;
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Hive tables created successfully${NC}"
else
    echo -e "${RED}⚠️  Failed to create Hive tables. HiveServer2 might still be starting.${NC}"
    echo -e "${YELLOW}   Run './scripts/create-tables.sh' manually after a few minutes${NC}"
fi


echo "Step 9: start smth2"
docker exec -d hive-server /opt/hive/bin/hive --service metastore
echo "End of Step 9"

echo ""

echo "=========================================="
echo -e "${GREEN}✅ Lab 3 Infrastructure is Ready!${NC}"
echo "=========================================="
echo ""
echo "🌐 Access Points:"
echo "  • Hadoop NameNode UI:  http://localhost:9870"
echo "  • NiFi UI:             http://localhost:8082/nifi"
echo "    Credentials:         admin / adminadminadmin"
echo "  • HiveServer2 JDBC:    jdbc:hive2://localhost:10000"
echo ""
echo "📝 Next Steps:"
echo "  1. Configure NiFi dataflow (Kafka → HDFS)"
echo "  2. Start MOEX collector to generate data"
echo "  3. Verify data in Hive: ./scripts/test.sh"
echo ""
echo "📖 See README.md for detailed instructions"
echo ""
