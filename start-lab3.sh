#!/bin/bash

# Скрипт для запуска Lab3 инфраструктуры (HDFS + Hive + NiFi)

set -e

echo "🚀 Starting Lab3 infrastructure (HDFS + Hive + NiFi)..."
echo ""

cd docker/lab3

# Проверка наличия конфигурационных файлов
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found!"
    exit 1
fi

if [ ! -f "hive-site.xml" ]; then
    echo "❌ Error: hive-site.xml not found!"
    exit 1
fi

# Создание директории для NiFi extensions (если нужно)
mkdir -p nifi-extensions

echo "📦 Starting services..."
echo "   This may take 3-5 minutes on first run..."
echo ""

# Запуск Docker Compose
docker-compose up -d

echo ""
echo "⏳ Waiting for services to initialize..."
echo ""

# Ждем PostgreSQL
echo "  → PostgreSQL..."
sleep 5

# Ждем HDFS
echo "  → HDFS NameNode..."
sleep 10

# Ждем Hive Metastore
echo "  → Hive Metastore (this may take 1-2 minutes)..."
sleep 60

# Ждем HiveServer2
echo "  → HiveServer2 (this may take 1-2 minutes)..."
sleep 60

# Ждем NiFi
echo "  → Apache NiFi (this may take 2-3 minutes)..."
sleep 90

echo ""
echo "🔍 Checking service status..."
docker-compose ps

echo ""
echo "✅ Lab3 infrastructure is starting!"
echo ""
echo "📊 Service URLs:"
echo "   • HDFS NameNode UI:    http://localhost:9870"
echo "   • HiveServer2 UI:      http://localhost:10002"
echo "   • Apache NiFi UI:      http://localhost:8080"
echo "   • NiFi HTTPS UI:       https://localhost:8443"
echo ""
echo "🔐 NiFi Credentials:"
echo "   Username: admin"
echo "   Password: adminadminadmin"
echo ""
echo "🔌 Connection Endpoints:"
echo "   • HDFS:                hdfs://localhost:9000"
echo "   • HiveServer2:         jdbc:hive2://localhost:10000"
echo "   • Hive Metastore:      thrift://localhost:9083"
echo "   • PostgreSQL:          jdbc:postgresql://localhost:5432/metastore"
echo ""
echo "📝 Useful commands:"
echo "   View logs:             cd docker/lab3 && docker-compose logs -f [service]"
echo "   Stop services:         ./stop-lab3.sh"
echo "   Remove all data:       cd docker/lab3 && docker-compose down -v"
echo ""
echo "⚠️  Note: Services may still be initializing. Check logs if you encounter issues."
echo "   Check Hive Metastore:  docker-compose logs -f hive-metastore"
echo "   Check HiveServer2:     docker-compose logs -f hiveserver2"
echo ""
