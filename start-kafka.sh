#!/bin/bash

# Скрипт для запуска Kafka инфраструктуры

set -e

echo "🚀 Starting Kafka infrastructure..."

cd docker/kafka

# Запуск Docker Compose
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Проверка состояния
docker-compose ps

echo ""
echo "✅ Kafka infrastructure is running!"
echo ""
echo "📊 Kafka UI: http://localhost:8080"
echo "🔌 Kafka Broker: localhost:9092"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop: docker-compose down"
echo "To stop and remove data: docker-compose down -v"
