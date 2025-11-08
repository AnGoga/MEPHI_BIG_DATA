#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting Hive Services"
echo "=========================================="

# Start Metastore in background
echo "📦 Starting Hive Metastore..."
nohup /opt/hive/bin/hive --service metastore > /tmp/metastore.log 2>&1 &

# Wait for Metastore to start
echo "⏳ Waiting for Metastore to be ready..."
sleep 15

# Check if Metastore port is listening
if netstat -tlnp | grep -q 9083; then
    echo "✅ Metastore is running on port 9083"
else
    echo "❌ Metastore failed to start"
    cat /tmp/metastore.log
    exit 1
fi

# Start HiveServer2 (foreground - keeps container alive)
echo "🚀 Starting HiveServer2..."
exec /opt/hive/bin/hive --service hiveserver2 --hiveconf hive.server2.enable.doAs=false
