#!/bin/bash

# Скрипт для остановки Kafka инфраструктуры

set -e

echo "🛑 Stopping Kafka infrastructure..."

cd docker/kafka

# Остановка Docker Compose
docker-compose down

echo ""
echo "✅ Kafka infrastructure stopped!"
echo ""
echo "To remove all data: docker-compose down -v"
