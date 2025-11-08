#!/bin/bash

# Скрипт для остановки Lab3 инфраструктуры

set -e

echo "🛑 Stopping Lab3 infrastructure..."

cd docker/lab3

# Остановка Docker Compose
docker-compose down

echo ""
echo "✅ Lab3 infrastructure stopped!"
echo ""
echo "To remove all data: cd docker/lab3 && docker-compose down -v"
echo "To start again: ./start-lab3.sh"
echo ""
