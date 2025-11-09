#!/bin/bash
set -e

echo "🛑 Stopping Lab 5: Spark Streaming"

cd "$(dirname "$0")/.."

docker-compose down

echo "✅ Lab 5 stopped"
echo ""
echo "💡 Tip: To remove all data, run:"
echo "   docker-compose down -v"
