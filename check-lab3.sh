#!/bin/bash

# Скрипт для проверки статуса Lab3 сервисов

echo "🔍 Checking Lab3 services status..."
echo ""

cd docker/lab3

echo "📊 Docker containers:"
docker-compose ps

echo ""
echo "🏥 Service health checks:"
echo ""

# PostgreSQL
echo -n "  PostgreSQL:         "
if docker exec lab3-postgres pg_isready -U hive -d metastore 2>/dev/null; then
    echo "✅ Ready"
else
    echo "❌ Not ready"
fi

# HDFS NameNode
echo -n "  HDFS NameNode:      "
if curl -sf http://localhost:9870 > /dev/null 2>&1; then
    echo "✅ Ready"
else
    echo "❌ Not ready"
fi

# Hive Metastore
echo -n "  Hive Metastore:     "
if docker exec lab3-hive-metastore netstat -an 2>/dev/null | grep -q 9083; then
    echo "✅ Ready"
else
    echo "❌ Not ready"
fi

# HiveServer2
echo -n "  HiveServer2:        "
if docker exec lab3-hiveserver2 netstat -an 2>/dev/null | grep -q 10000; then
    echo "✅ Ready"
else
    echo "❌ Not ready"
fi

# NiFi
echo -n "  Apache NiFi:        "
if curl -sf http://localhost:8080/nifi > /dev/null 2>&1; then
    echo "✅ Ready"
else
    echo "❌ Not ready (may take 3-5 minutes after start)"
fi

echo ""
echo "📝 To view detailed logs:"
echo "   cd docker/lab3"
echo "   docker-compose logs -f [service-name]"
echo ""
echo "Available services:"
echo "   postgres, namenode, datanode, hive-metastore, hiveserver2, nifi"
echo ""
