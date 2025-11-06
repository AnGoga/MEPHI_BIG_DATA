# Hadoop/Hive/NiFi Infrastructure - Lab 3

Этот Docker Compose стек предоставляет полную инфраструктуру для хранения и обработки больших данных из Московской Биржи (MOEX).

## Компоненты

### 1. HDFS (Hadoop Distributed File System)
- **NameNode** - мастер-узел, управляет метаданными файловой системы
- **DataNode 1, 2** - рабочие узлы, хранят данные (репликация: 2 копии)

### 2. Apache Hive
- **Metastore** - хранит метаданные таблиц (схемы, партиции)
- **HiveServer2** - SQL интерфейс для выполнения запросов
- **PostgreSQL** - база данных для Metastore

### 3. Apache NiFi
- ETL инструмент для перекачки данных из Kafka в HDFS
- Визуальный интерфейс для настройки data pipelines

## Быстрый старт

### 1. Запуск инфраструктуры

```bash
# Из корневой директории проекта
./start-hadoop.sh
```

Скрипт:
- Проверяет что Kafka запущена
- Запускает все компоненты Hadoop/Hive/NiFi
- Выводит ссылки на Web UI

### 2. Инициализация HDFS

```bash
./init-hdfs.sh
```

Создает необходимые директории:
- `/user/moex/trades` - для сделок
- `/user/moex/instruments` - для инструментов
- `/user/hive/warehouse` - для Hive таблиц

### 3. Создание таблиц в Hive

```bash
./init-hive.sh
```

Создает:
- База данных `moex_data`
- Таблица `trades` (партиционирована по дате)
- Таблица `instruments`
- Views для аналитики

### 4. Проверка статуса

```bash
./check-hadoop.sh
```

Показывает:
- Статус Docker контейнеров
- Состояние HDFS кластера
- Список таблиц в Hive
- Ссылки на Web UI

## Web Interfaces

После запуска доступны следующие интерфейсы:

| Сервис | URL | Описание |
|--------|-----|----------|
| **HDFS NameNode** | http://localhost:9870 | Мониторинг HDFS, просмотр файлов |
| **HiveServer2** | http://localhost:10002 | Статус HiveServer2 |
| **NiFi** | https://localhost:8443/nifi | ETL pipeline редактор |

**NiFi credentials:**
- Username: `admin`
- Password: `adminadminadmin`

## Подключение к сервисам

### HDFS CLI

```bash
# Просмотр файлов
docker exec hdfs-namenode hdfs dfs -ls /user/moex

# Создать директорию
docker exec hdfs-namenode hdfs dfs -mkdir /user/moex/test

# Загрузить файл
docker exec hdfs-namenode hdfs dfs -put /tmp/data.txt /user/moex/

# Скачать файл
docker exec hdfs-namenode hdfs dfs -get /user/moex/data.txt /tmp/

# Удалить файл
docker exec hdfs-namenode hdfs dfs -rm /user/moex/data.txt

# Статистика кластера
docker exec hdfs-namenode hdfs dfsadmin -report
```

### Hive Beeline (SQL клиент)

```bash
# Подключиться к HiveServer2
docker exec -it hiveserver2 /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000

# В beeline prompt:
USE moex_data;
SHOW TABLES;
SELECT * FROM trades LIMIT 10;

# Выполнить запрос из файла
docker exec hiveserver2 /opt/hive/bin/beeline \
    -u jdbc:hive2://localhost:10000 \
    -f /tmp/query.sql
```

### Примеры HiveQL запросов

```sql
-- Использовать базу данных
USE moex_data;

-- Обновить информацию о партициях (после загрузки данных)
MSCK REPAIR TABLE trades;

-- Показать партиции
SHOW PARTITIONS trades;

-- Количество сделок по датам
SELECT trade_date, COUNT(*) as trade_count
FROM trades
GROUP BY trade_date
ORDER BY trade_date DESC;

-- Топ 10 инструментов по объему торгов за день
SELECT
    sec_id,
    COUNT(*) as trade_count,
    SUM(value) as total_value,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price
FROM trades
WHERE trade_date = '2025-11-06'
GROUP BY sec_id
ORDER BY total_value DESC
LIMIT 10;

-- Join с инструментами
SELECT
    t.sec_id,
    i.short_name,
    i.sec_name,
    COUNT(*) as trade_count,
    SUM(t.value) as total_value
FROM trades t
JOIN instruments i ON t.sec_id = i.sec_id
WHERE t.trade_date = '2025-11-06'
GROUP BY t.sec_id, i.short_name, i.sec_name
ORDER BY total_value DESC
LIMIT 10;

-- Почасовая динамика цен
SELECT
    sec_id,
    SUBSTRING(trade_time, 1, 2) as hour,
    AVG(price) as avg_price,
    COUNT(*) as trade_count
FROM trades
WHERE trade_date = '2025-11-06'
  AND sec_id = 'SBER'
GROUP BY sec_id, SUBSTRING(trade_time, 1, 2)
ORDER BY hour;
```

## Настройка NiFi Pipeline

### Цель
Перекачивать данные из Kafka топика `moex.trades` в HDFS с партиционированием по дате.

### Шаги настройки

1. **Открыть NiFi UI**
   - URL: https://localhost:8443/nifi
   - Login: admin / adminadminadmin

2. **Создать Processor Group** (опционально)
   - Правый клик на canvas → "Add Process Group"
   - Название: "Kafka to HDFS Pipeline"

3. **Добавить ConsumeKafka_2_6 процессор**
   - Перетащить процессор на canvas
   - Настройки:
     - **Kafka Brokers**: `moex-kafka:9092`
     - **Topic Name(s)**: `moex.trades`
     - **Group ID**: `nifi-hdfs-consumer`
     - **Message Demarcator**: оставить пустым (каждое сообщение отдельно)
   - Relationships → Auto-terminate: `failure`

4. **Добавить EvaluateJsonPath процессор**
   - Для извлечения даты из JSON
   - Настройки:
     - **Destination**: flowfile-attribute
     - **Return Type**: json
     - Добавить property `trade_date`: `$.tradetime`
   - Подключить: ConsumeKafka → EvaluateJsonPath

5. **Добавить UpdateAttribute процессор**
   - Для форматирования пути HDFS
   - Настройки:
     - Добавить property `filename`: `${now():format('yyyyMMddHHmmss')}_${UUID()}.json`
     - Добавить property `hdfs.path`: `/user/moex/trades/trade_date=${now():format('yyyy-MM-dd')}/`
   - Подключить: EvaluateJsonPath → UpdateAttribute

6. **Добавить PutHDFS процессор**
   - Для записи в HDFS
   - Настройки:
     - **Hadoop Configuration Resources**: `/opt/hadoop/etc/hadoop/core-site.xml,/opt/hadoop/etc/hadoop/hdfs-site.xml`
     - **Directory**: `${hdfs.path}`
     - **Conflict Resolution Strategy**: replace
   - Подключить: UpdateAttribute → PutHDFS
   - Relationships → Auto-terminate: `success`, `failure`

7. **Запустить процессоры**
   - Выбрать все процессоры
   - Правый клик → Start

### Альтернатива: MergeContent + PutHDFS

Для оптимизации (чтобы не создавать тысячи маленьких файлов):

1. После UpdateAttribute добавить **MergeContent**
   - **Merge Strategy**: Bin-Packing Algorithm
   - **Merge Format**: Binary Concatenation
   - **Minimum Number of Entries**: 1000
   - **Maximum Bin Age**: 5 minutes
   - **Delimiter Strategy**: Text
   - **Demarcator**: `\n` (новая строка между JSON объектами)

2. Затем PutHDFS как обычно

## Проверка загрузки данных

### 1. Проверить файлы в HDFS

```bash
# Список файлов
docker exec hdfs-namenode hdfs dfs -ls -R /user/moex/trades

# Посмотреть содержимое файла
docker exec hdfs-namenode hdfs dfs -cat /user/moex/trades/trade_date=2025-11-06/*.json | head -10

# Размер данных
docker exec hdfs-namenode hdfs dfs -du -h /user/moex/trades
```

### 2. Обновить партиции в Hive

```bash
docker exec hiveserver2 /opt/hive/bin/beeline \
    -u jdbc:hive2://localhost:10000 \
    -e "MSCK REPAIR TABLE moex_data.trades;"
```

### 3. Проверить данные через Hive

```bash
docker exec hiveserver2 /opt/hive/bin/beeline \
    -u jdbc:hive2://localhost:10000 \
    -e "USE moex_data; SELECT COUNT(*) FROM trades;"
```

## Архитектура данных

```
moex-collector (Kotlin)
        ↓
   Apache Kafka
   (moex.trades)
        ↓
   Apache NiFi
   (ETL pipeline)
        ↓
      HDFS
/user/moex/trades/
├── trade_date=2025-11-06/
│   ├── part-00001.json
│   ├── part-00002.json
│   └── ...
├── trade_date=2025-11-07/
│   └── ...
        ↓
   Apache Hive
   (SQL queries)
```

## Формат данных

### JSON в Kafka/HDFS
```json
{
  "tradeNo": 14647830970,
  "tradeTime": "10:00:01",
  "securityId": "SBER",
  "boardId": "TQBR",
  "price": 258.50,
  "quantity": 100,
  "value": 25850.00,
  "buySell": "B"
}
```

### Parquet в Hive
- Колоночный формат
- Сжатие SNAPPY
- Партиционирование по `trade_date`

## Мониторинг и отладка

### Логи контейнеров

```bash
# Все логи
docker-compose logs

# Конкретный сервис
docker-compose logs namenode
docker-compose logs hiveserver2
docker-compose logs nifi

# Следить за логами в реальном времени
docker-compose logs -f nifi
```

### Состояние HDFS

```bash
# Статус кластера
docker exec hdfs-namenode hdfs dfsadmin -report

# Проверка файловой системы
docker exec hdfs-namenode hdfs fsck /

# Информация о DataNodes
docker exec hdfs-namenode hdfs dfsadmin -printTopology
```

### Проблемы и решения

#### NameNode не запускается
```bash
# Проверить логи
docker-compose logs namenode

# Пересоздать с очисткой данных (ВНИМАНИЕ: удалит все данные!)
docker-compose down -v
docker-compose up -d
```

#### HiveServer2 не может подключиться к Metastore
```bash
# Проверить что PostgreSQL запущен
docker-compose ps postgres-metastore

# Проверить что Metastore запущен
docker-compose logs hive-metastore

# Переинициализировать схему Metastore
docker exec hive-metastore /opt/hive/bin/schematool -dbType postgres -initSchema
```

#### NiFi не может записать в HDFS
```bash
# Проверить права доступа в HDFS
docker exec hdfs-namenode hdfs dfs -ls /user/moex

# Дать полные права (для разработки)
docker exec hdfs-namenode hdfs dfs -chmod -R 777 /user/moex

# Проверить что NameNode доступен из NiFi
docker exec apache-nifi ping namenode
```

## Управление

### Остановка инфраструктуры

```bash
./stop-hadoop.sh

# Или напрямую:
cd docker/hadoop
docker-compose down
```

### Полная очистка (удаление данных)

```bash
cd docker/hadoop
docker-compose down -v  # -v удаляет volumes
```

### Перезапуск отдельного сервиса

```bash
docker-compose restart namenode
docker-compose restart hiveserver2
docker-compose restart nifi
```

## Следующие шаги

После успешной настройки Лабы 3:

1. ✅ Kafka работает (Лаба 1-2)
2. ✅ HDFS кластер запущен
3. ✅ Hive таблицы созданы
4. ✅ NiFi pipeline настроен
5. ⏭️ **Лаба 4**: MapReduce batch processing
6. ⏭️ **Лаба 5**: Spark Streaming
7. ⏭️ **Лаба 6**: Визуализация в Apache Superset

## Полезные ссылки

- [Apache Hadoop Documentation](https://hadoop.apache.org/docs/stable/)
- [Apache Hive Documentation](https://hive.apache.org/)
- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [MOEX ISS API](https://iss.moex.com/iss/reference/)
