#!/bin/bash

# Скрипт проверки Lab3 инфраструктуры

echo "╔════════════════════════════════════════╗"
echo "║  Lab3 Infrastructure Status            ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Проверка контейнеров
echo "📦 Container Status:"
docker-compose ps
echo ""

# Проверка здоровья сервисов
echo "🏥 Service Health:"
echo ""

# PostgreSQL
echo -n "   PostgreSQL (5432):        "
if docker exec lab3-postgres pg_isready -U hive -d metastore 2>/dev/null | grep -q "accepting"; then
    echo "✅ Ready"
else
    echo "❌ Not Ready"
fi

# HDFS NameNode
echo -n "   HDFS NameNode (9870):     "
if curl -sf http://localhost:9870 > /dev/null 2>&1; then
    echo "✅ Ready"
else
    echo "❌ Not Ready"
fi

# HDFS DataNode
echo -n "   HDFS DataNode (9864):     "
if curl -sf http://localhost:9864 > /dev/null 2>&1; then
    echo "✅ Ready"
else
    echo "❌ Not Ready"
fi

# Hive Metastore
echo -n "   Hive Metastore (9083):    "
if docker exec lab3-hive-metastore netstat -tuln 2>/dev/null | grep -q 9083; then
    echo "✅ Ready"
else
    echo "❌ Not Ready"
fi

# HiveServer2
echo -n "   HiveServer2 (10000):      "
if docker exec lab3-hiveserver2 netstat -tuln 2>/dev/null | grep -q 10000; then
    echo "✅ Ready"
else
    echo "❌ Not Ready"
fi

# NiFi
echo -n "   Apache NiFi (8080):       "
if curl -sf http://localhost:8080/nifi > /dev/null 2>&1; then
    echo "✅ Ready"
else
    echo "⚠️  Starting (may take 3-5 minutes)"
fi

echo ""
echo "🔌 Port Check:"
echo ""

# Проверка портов
for port in 5432 9000 9870 9864 9083 10000 10002 8080; do
    echo -n "   Port $port: "
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo "✅ Listening"
    else
        echo "❌ Not listening"
    fi
done

echo ""
echo "📊 Quick Tests:"
echo ""

# Test PostgreSQL
echo -n "   PostgreSQL tables: "
TABLE_COUNT=$(docker exec lab3-postgres psql -U hive -d metastore -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null | tr -d ' ')
if [ "$TABLE_COUNT" -gt 0 ] 2>/dev/null; then
    echo "✅ $TABLE_COUNT tables found"
else
    echo "⚠️  No tables (Metastore schema not initialized)"
fi

# Test HDFS
echo -n "   HDFS filesystem:   "
if docker exec lab3-namenode hdfs dfs -ls / 2>/dev/null > /dev/null; then
    echo "✅ Accessible"
else
    echo "❌ Not accessible"
fi

# Test Hive connection
echo -n "   Hive connection:   "
if docker exec lab3-hiveserver2 beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" 2>/dev/null | grep -q "default"; then
    echo "✅ Working"
else
    echo "⚠️  Not ready yet"
fi

echo ""
echo "📝 Useful Commands:"
echo "   View logs:          docker-compose logs -f [service]"
echo "   Restart service:    docker-compose restart [service]"
echo "   Connect to Hive:    docker exec -it lab3-hiveserver2 beeline -u jdbc:hive2://localhost:10000"
echo "   Check HDFS:         docker exec lab3-namenode hdfs dfs -ls /"
echo ""
echo "Services: postgres, namenode, datanode, hive-metastore, hiveserver2, nifi"
echo ""
