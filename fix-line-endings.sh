#!/bin/bash

# Скрипт для исправления line endings (CRLF -> LF) в shell скриптах
# Полезно при работе в WSL/Windows

echo "🔧 Fixing line endings for shell scripts..."
echo ""

# Найти и исправить все .sh файлы
find . -name "*.sh" -type f -exec sed -i 's/\r$//' {} \;

echo "✅ Fixed line endings for all .sh files"
echo ""
echo "📝 Affected files:"
find . -name "*.sh" -type f

echo ""
echo "✅ Done! You can now run scripts with ./script.sh"
