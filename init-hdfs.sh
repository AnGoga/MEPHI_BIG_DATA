#!/bin/bash

# Скрипт для инициализации директорий в HDFS

set -e

echo "📁 Initializing HDFS directories..."
echo ""

# Проверка что NameNode запущен
if ! docker ps | grep -q hdfs-namenode; then
    echo "❌ Error: HDFS NameNode is not running!"
    echo "   Please run: ./start-hadoop.sh"
    exit 1
fi

echo "Creating HDFS directories..."

# Создание базовых директорий
docker exec hdfs-namenode hdfs dfs -mkdir -p /user/moex
docker exec hdfs-namenode hdfs dfs -mkdir -p /user/moex/trades
docker exec hdfs-namenode hdfs dfs -mkdir -p /user/moex/instruments
docker exec hdfs-namenode hdfs dfs -mkdir -p /user/moex/raw
docker exec hdfs-namenode hdfs dfs -mkdir -p /user/hive/warehouse
docker exec hdfs-namenode hdfs dfs -mkdir -p /tmp

# Установка прав доступа
docker exec hdfs-namenode hdfs dfs -chmod -R 777 /user/moex
docker exec hdfs-namenode hdfs dfs -chmod -R 777 /user/hive
docker exec hdfs-namenode hdfs dfs -chmod -R 777 /tmp

echo ""
echo "📊 HDFS directory structure:"
docker exec hdfs-namenode hdfs dfs -ls -R /user

echo ""
echo "✅ HDFS directories initialized successfully!"
echo ""
echo "📝 Next step: Initialize Hive tables"
echo "   Run: ./init-hive.sh"
