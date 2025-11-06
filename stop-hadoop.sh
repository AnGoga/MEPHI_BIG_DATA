#!/bin/bash

# Скрипт для остановки Hadoop/Hive/NiFi инфраструктуры (Лаба 3)

set -e

echo "🛑 Stopping Hadoop/Hive/NiFi infrastructure (Lab 3)..."
echo ""

cd docker/hadoop

# Остановка контейнеров
docker-compose down

echo ""
echo "=================================================="
echo "✅ Hadoop/Hive/NiFi infrastructure stopped!"
echo "=================================================="
echo ""
echo "💡 Tips:"
echo "   - Data is preserved in Docker volumes"
echo "   - To start again: ./start-hadoop.sh"
echo "   - To remove all data: docker-compose down -v"
echo "=================================================="
