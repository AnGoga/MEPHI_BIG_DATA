#!/bin/bash

# Скрипт для запуска Hadoop/Hive/NiFi инфраструктуры (Лаба 3)

set -e

echo "🚀 Starting Hadoop/Hive/NiFi infrastructure (Lab 3)..."
echo ""

# Проверка что Kafka запущена
echo "📋 Checking if Kafka is running..."
if ! docker ps | grep -q moex-kafka; then
    echo "⚠️  Kafka is not running! Starting Kafka first..."
    cd docker/kafka
    docker-compose up -d
    cd ../..
    echo "✅ Kafka started"
    echo "⏳ Waiting 10 seconds for Kafka to be ready..."
    sleep 10
else
    echo "✅ Kafka is already running"
fi

echo ""
echo "📋 Starting Hadoop cluster..."
cd docker/hadoop

# Запуск инфраструктуры
docker-compose up -d

echo ""
echo "⏳ Waiting for services to start..."
echo "   This may take 1-2 minutes..."
sleep 30

echo ""
echo "📊 Checking service status..."
docker-compose ps

echo ""
echo "=================================================="
echo "✅ Hadoop/Hive/NiFi infrastructure started!"
echo "=================================================="
echo ""
echo "🌐 Web Interfaces:"
echo "   - HDFS NameNode UI:    http://localhost:9870"
echo "   - HiveServer2 UI:      http://localhost:10002"
echo "   - NiFi UI (HTTPS):     https://localhost:8443/nifi"
echo "     (username: admin, password: adminadminadmin)"
echo ""
echo "🔌 Service Ports:"
echo "   - HDFS NameNode:       hdfs://localhost:9000"
echo "   - Hive Metastore:      thrift://localhost:9083"
echo "   - HiveServer2:         jdbc:hive2://localhost:10000"
echo "   - PostgreSQL:          localhost:5433"
echo ""
echo "📝 Next steps:"
echo "   1. Initialize HDFS directories:"
echo "      ./init-hdfs.sh"
echo ""
echo "   2. Create Hive tables:"
echo "      ./init-hive.sh"
echo ""
echo "   3. Configure NiFi pipeline:"
echo "      Open https://localhost:8443/nifi"
echo "      See docker/hadoop/README.md for NiFi setup instructions"
echo ""
echo "   4. Check logs:"
echo "      docker-compose -f docker/hadoop/docker-compose.yml logs -f"
echo "=================================================="
