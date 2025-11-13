#!/bin/bash

# Stop script for Lab 6: Data Visualization

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================="
echo "🛑 Stopping Lab 6: Data Visualization"
echo "=================================================="
echo ""

cd "$PROJECT_ROOT"

# Stop services
echo "⏳ Stopping services..."
docker-compose down

echo ""
echo "✅ Lab 6 services stopped!"
echo ""
echo "💡 To remove all data volumes, run:"
echo "   docker-compose down -v"
echo ""
