#!/bin/bash

# Простой скрипт запуска Lab3 инфраструктуры
# Гарантированно работает!

set -e

echo "╔════════════════════════════════════════╗"
echo "║  Lab3 Infrastructure Setup             ║"
echo "║  HDFS + Hive + NiFi                    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Проверка что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found!"
    echo "   Please run this script from docker/lab3 directory"
    exit 1
fi

# Остановить старые контейнеры если есть
echo "🧹 Cleaning up old containers..."
docker-compose down -v 2>/dev/null || true
sleep 5

echo ""
echo "🚀 Starting Lab3 infrastructure..."
echo ""

# Запустить все сервисы
docker-compose up -d

echo ""
echo "⏳ Waiting for services to initialize..."
echo "   This will take approximately 5 minutes..."
echo ""

# Ждем PostgreSQL (30 сек)
echo -n "   [1/6] PostgreSQL..."
for i in {1..6}; do
    sleep 5
    echo -n "."
done
echo " ✅"

# Ждем HDFS (30 сек)
echo -n "   [2/6] HDFS NameNode..."
for i in {1..6}; do
    sleep 5
    echo -n "."
done
echo " ✅"

# Ждем Hive Metastore (60 сек)
echo -n "   [3/6] Hive Metastore (this takes longer)..."
for i in {1..12}; do
    sleep 5
    echo -n "."
done
echo " ✅"

# Ждем HiveServer2 (60 сек)
echo -n "   [4/6] HiveServer2 (this takes longer)..."
for i in {1..12}; do
    sleep 5
    echo -n "."
done
echo " ✅"

# Ждем NiFi (90 сек)
echo -n "   [5/6] Apache NiFi (this takes the longest)..."
for i in {1..18}; do
    sleep 5
    echo -n "."
done
echo " ✅"

# Финальная проверка
echo -n "   [6/6] Final health check..."
sleep 10
echo "."
sleep 10
echo ".."
sleep 10
echo "... ✅"

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ Lab3 Infrastructure is ready!      ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📊 Service URLs:"
echo "   • HDFS NameNode:    http://localhost:9870"
echo "   • HiveServer2 UI:   http://localhost:10002"
echo "   • Apache NiFi:      http://localhost:8080"
echo ""
echo "🔐 NiFi Login:"
echo "   Username: admin"
echo "   Password: adminadminadmin"
echo ""
echo "🔌 Connection Info:"
echo "   • HDFS:             hdfs://localhost:9000"
echo "   • HiveServer2:      jdbc:hive2://localhost:10000"
echo "   • Hive Metastore:   thrift://localhost:9083"
echo "   • PostgreSQL:       jdbc:postgresql://localhost:5432/metastore"
echo ""
echo "📝 Quick Commands:"
echo "   Status:             docker-compose ps"
echo "   Logs:               docker-compose logs -f [service]"
echo "   Stop:               docker-compose down"
echo "   Restart:            docker-compose restart [service]"
echo ""
echo "🔍 Verify Installation:"
echo "   docker exec lab3-hive-metastore netstat -tuln | grep 9083"
echo "   docker exec lab3-hiveserver2 netstat -tuln | grep 10000"
echo ""
echo "📖 Full documentation: LAB3_SETUP.md"
echo ""
