#!/bin/bash

# Скрипт для запуска MOEX collector приложения

set -e

echo "🚀 Starting MOEX Collector..."

cd moex-collector

# Сборка проекта
echo "📦 Building project..."
./gradlew build -x test

# Запуск приложения
echo "▶️  Running application..."
./gradlew bootRun
