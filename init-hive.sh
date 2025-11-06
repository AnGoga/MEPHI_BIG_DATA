#!/bin/bash

# Скрипт для инициализации таблиц в Hive

set -e

echo "🗄️  Initializing Hive tables..."
echo ""

# Проверка что HiveServer2 запущен
if ! docker ps | grep -q hiveserver2; then
    echo "❌ Error: HiveServer2 is not running!"
    echo "   Please run: ./start-hadoop.sh"
    exit 1
fi

echo "⏳ Waiting for HiveServer2 to be ready..."
sleep 10

echo "📝 Creating database and tables..."

# Копировать SQL скрипт в контейнер
docker cp docker/hadoop/init-scripts/create-tables.sql hiveserver2:/tmp/create-tables.sql

# Выполнить SQL скрипт
docker exec hiveserver2 /opt/hive/bin/beeline \
    -u jdbc:hive2://localhost:10000 \
    -n hive \
    --silent=true \
    -f /tmp/create-tables.sql

echo ""
echo "📊 Checking created tables..."
docker exec hiveserver2 /opt/hive/bin/beeline \
    -u jdbc:hive2://localhost:10000 \
    -n hive \
    --silent=true \
    -e "USE moex_data; SHOW TABLES;"

echo ""
echo "✅ Hive tables created successfully!"
echo ""
echo "📝 Available tables in moex_data database:"
echo "   - trades (partitioned by trade_date)"
echo "   - instruments"
echo "   - daily_trades_summary (view)"
echo "   - top_traded_securities (view)"
echo ""
echo "💡 To query data via Hive:"
echo "   docker exec -it hiveserver2 /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000"
echo "   Then run: USE moex_data; SELECT * FROM trades LIMIT 10;"
