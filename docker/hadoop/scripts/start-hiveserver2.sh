#!/bin/bash
set -e

# Настройка переменных окружения
export HIVE_CONF_DIR=/opt/hive/conf
export HADOOP_CLASSPATH="${HADOOP_CLASSPATH}:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/hdfs/lib/*:/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/yarn/*:/opt/hadoop/share/hadoop/yarn/lib/*"

# Создаём директорию для логов
mkdir -p /tmp/hive-logs

# Запускаем HiveServer2 в фоне, перенаправляя вывод в лог
nohup /opt/hive/bin/hive --skiphadoopversion --skiphbasecp --service hiveserver2 \
  > /tmp/hive-logs/hiveserver2.log 2>&1 &

# Сохраняем PID
HIVE_PID=$!
echo "HiveServer2 started with PID: $HIVE_PID"

# Ждём немного чтобы убедиться что процесс стартовал
sleep 5

# Проверяем что процесс ещё жив
if ! kill -0 $HIVE_PID 2>/dev/null; then
  echo "ERROR: HiveServer2 failed to start!"
  cat /tmp/hive-logs/hiveserver2.log
  exit 1
fi

echo "HiveServer2 is running. Tailing logs..."

# Tail логов чтобы контейнер оставался живым
exec tail -f /tmp/hive-logs/hiveserver2.log
