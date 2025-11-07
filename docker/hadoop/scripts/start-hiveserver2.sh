#!/bin/bash
set -e

# Настройка переменных окружения
export HIVE_CONF_DIR=/opt/hive/conf
export HADOOP_CLASSPATH="${HADOOP_CLASSPATH}:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/hdfs/lib/*:/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/yarn/*:/opt/hadoop/share/hadoop/yarn/lib/*"

echo "Patching HiveServer2 startup script to remove PID check..."

# Создаём патченную версию скрипта hiveserver2 без проверки "already running"
# Копируем оригинальный скрипт и удаляем секцию проверки PID
cp /opt/hive/bin/hiveserver2 /tmp/hiveserver2-patched

# Удаляем проверку на уже запущенный процесс
# Заменяем всю секцию проверки на no-op
sed -i '/HiveServer2 running as process/,/exit 1/d' /tmp/hiveserver2-patched
sed -i '/ps -ef.*HiveServer2/d' /tmp/hiveserver2-patched

chmod +x /tmp/hiveserver2-patched

# Создаём патченную версию hive wrapper
mkdir -p /tmp/hive-bin
cp -r /opt/hive/bin/* /tmp/hive-bin/
cp /tmp/hiveserver2-patched /tmp/hive-bin/hiveserver2

echo "Starting HiveServer2 with patched script..."

# Запускаем HiveServer2 напрямую используя патченный скрипт
exec /tmp/hive-bin/hiveserver2
