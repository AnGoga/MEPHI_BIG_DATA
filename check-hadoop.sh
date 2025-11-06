#!/bin/bash

# Скрипт для проверки статуса Hadoop/Hive/NiFi инфраструктуры

echo "🔍 Checking Hadoop/Hive/NiFi infrastructure status..."
echo ""

cd docker/hadoop

echo "=================================================="
echo "📊 Docker Containers Status"
echo "=================================================="
docker-compose ps

echo ""
echo "=================================================="
echo "📁 HDFS Status"
echo "=================================================="
if docker ps | grep -q hdfs-namenode; then
    docker exec hdfs-namenode hdfs dfsadmin -report
else
    echo "❌ HDFS NameNode is not running"
fi

echo ""
echo "=================================================="
echo "📂 HDFS Directory Structure"
echo "=================================================="
if docker ps | grep -q hdfs-namenode; then
    docker exec hdfs-namenode hdfs dfs -ls -R /user | head -20
else
    echo "❌ HDFS NameNode is not running"
fi

echo ""
echo "=================================================="
echo "🗄️  Hive Tables"
echo "=================================================="
if docker ps | grep -q hiveserver2; then
    docker exec hiveserver2 /opt/hive/bin/beeline \
        -u jdbc:hive2://localhost:10000 \
        -n hive \
        --silent=true \
        -e "USE moex_data; SHOW TABLES;" 2>/dev/null || echo "❌ HiveServer2 not ready or tables not created"
else
    echo "❌ HiveServer2 is not running"
fi

echo ""
echo "=================================================="
echo "🌐 Web Interfaces"
echo "=================================================="
echo "HDFS NameNode:     http://localhost:9870"
echo "HiveServer2 UI:    http://localhost:10002"
echo "NiFi UI:           https://localhost:8443/nifi"
echo "PostgreSQL:        localhost:5433"
echo "=================================================="
