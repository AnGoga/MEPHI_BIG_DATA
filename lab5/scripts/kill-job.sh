#!/bin/bash

echo "=========================================="
echo "🛑 Stopping Spark Streaming Job"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# Check if Spark Master is running
if ! docker ps | grep -q "moex-spark-master"; then
    echo -e "${RED}❌ Spark Master is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}Finding running Spark jobs...${NC}"
echo ""

# Get active applications
APP_INFO=$(curl -s http://localhost:8083/json/ 2>/dev/null)

if [ -z "$APP_INFO" ]; then
    echo -e "${RED}❌ Cannot connect to Spark Master API${NC}"
    echo "Make sure Spark Master is accessible at http://localhost:8083"
    exit 1
fi

# Extract application IDs
APP_IDS=$(echo "$APP_INFO" | grep -o '"id":"app-[^"]*"' | cut -d'"' -f4)

if [ -z "$APP_IDS" ]; then
    echo -e "${YELLOW}No active Spark applications found${NC}"
    echo ""
    echo "Alternative: Kill spark-submit process directly"
    echo ""

    # Find and kill spark-submit processes
    PIDS=$(docker exec moex-spark-master ps aux | grep "spark-submit" | grep -v grep | awk '{print $2}')

    if [ -z "$PIDS" ]; then
        echo -e "${GREEN}✅ No spark-submit processes running${NC}"
        exit 0
    else
        echo "Found spark-submit processes:"
        docker exec moex-spark-master ps aux | grep "spark-submit" | grep -v grep
        echo ""
        read -p "Kill these processes? (y/n) " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$PIDS" | while read pid; do
                echo "Killing PID $pid..."
                docker exec moex-spark-master kill -9 "$pid" 2>/dev/null || true
            done
            echo -e "${GREEN}✅ Processes killed${NC}"
        else
            echo "Cancelled."
        fi
    fi
    exit 0
fi

echo "Active applications:"
echo "$APP_IDS" | nl
echo ""

# If only one app, kill it automatically
APP_COUNT=$(echo "$APP_IDS" | wc -l)

if [ "$APP_COUNT" -eq 1 ]; then
    APP_ID="$APP_IDS"
    echo -e "${YELLOW}Killing application: $APP_ID${NC}"

    docker exec moex-spark-master /opt/bitnami/spark/bin/spark-class \
      org.apache.spark.deploy.Client \
      kill spark://spark-master:7077 "$APP_ID" 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Failed to kill via Spark API, trying direct kill...${NC}"

        # Fallback: kill process
        PIDS=$(docker exec moex-spark-master ps aux | grep "$APP_ID" | grep -v grep | awk '{print $2}')
        if [ ! -z "$PIDS" ]; then
            echo "$PIDS" | while read pid; do
                docker exec moex-spark-master kill -9 "$pid" 2>/dev/null || true
            done
        fi
    }

    echo -e "${GREEN}✅ Job killed${NC}"
else
    # Multiple apps - ask which one to kill
    read -p "Enter application number to kill (or 'all' to kill all): " APP_NUM

    if [ "$APP_NUM" = "all" ]; then
        echo "$APP_IDS" | while read APP_ID; do
            echo "Killing $APP_ID..."
            docker exec moex-spark-master /opt/bitnami/spark/bin/spark-class \
              org.apache.spark.deploy.Client \
              kill spark://spark-master:7077 "$APP_ID" 2>/dev/null || true
        done
        echo -e "${GREEN}✅ All jobs killed${NC}"
    else
        APP_ID=$(echo "$APP_IDS" | sed -n "${APP_NUM}p")
        if [ -z "$APP_ID" ]; then
            echo -e "${RED}❌ Invalid application number${NC}"
            exit 1
        fi

        echo "Killing $APP_ID..."
        docker exec moex-spark-master /opt/bitnami/spark/bin/spark-class \
          org.apache.spark.deploy.Client \
          kill spark://spark-master:7077 "$APP_ID"

        echo -e "${GREEN}✅ Job killed${NC}"
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Done!${NC}"
echo "=========================================="
echo ""
