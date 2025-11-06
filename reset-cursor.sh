#!/bin/bash

# Скрипт для сброса курсора сбора данных
# После выполнения этого скрипта Initial Load выполнится заново

set -e

CURSOR_FILE="moex-collector/data/collection-cursor.json"

echo "🔄 Resetting collection cursor..."

if [ -f "$CURSOR_FILE" ]; then
    echo "📄 Found cursor file: $CURSOR_FILE"
    cat "$CURSOR_FILE"
    echo ""

    echo "🗑️  Removing cursor file..."
    rm "$CURSOR_FILE"
    echo "✅ Cursor file removed!"
else
    echo "⚠️  Cursor file not found: $CURSOR_FILE"
    echo "   (Already clean or first run)"
fi

echo ""
echo "✅ Cursor reset complete!"
echo ""
echo "Next steps:"
echo "1. Start the collector: ./run-collector.sh"
echo "2. Initial Load will run and collect all trades from the beginning of the day"
