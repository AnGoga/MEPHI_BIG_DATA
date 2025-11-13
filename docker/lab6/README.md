# Лабораторная работа №6: Визуализация данных

**Цель**: Визуализировать обработанные данные с использованием Apache Superset. Использовать Apache Pinot для хранения и быстрого анализа потоковых данных.

---

## 📊 Архитектура решения

```
┌─────────────────────────────────────────────────────────┐
│              ИСТОЧНИКИ ДАННЫХ (Labs 1-5)                │
├─────────────────────────────────────────────────────────┤
│  Kafka Topic: moex.current_prices (Lab 5)              │
│  Hive Table: moex_data.trades (Lab 3)                  │
│  Hive Table: moex_data.trade_volumes_hourly (Lab 4)    │
└────────────────────┬───────────────┬────────────────────┘
                     │               │
                     ↓               ↓
         ┌───────────────────┐   ┌──────────────┐
         │  Apache Pinot     │   │ Apache Hive  │
         │  (Real-time OLAP) │   │ (Batch Data) │
         │                   │   │              │
         │  Table:           │   │  Tables:     │
         │  current_prices   │   │  - trades    │
         │                   │   │  - volumes   │
         └────────┬──────────┘   └──────┬───────┘
                  │                     │
                  └──────────┬──────────┘
                             ↓
                  ┌──────────────────────┐
                  │  Apache Superset     │
                  │  (Visualization)     │
                  │                      │
                  │  Dashboards:         │
                  │  1. Batch Analytics  │
                  │  2. Real-time Prices │
                  └──────────────────────┘
```

---

## 🛠️ Технологический стек

| Компонент | Технология | Версия | Порты |
|-----------|-----------|--------|-------|
| **Real-time OLAP** | Apache Pinot | 1.0.0 | 9001 (Controller), 8099 (Broker), 8098 (Server) |
| **Visualization** | Apache Superset | 3.0.0 | 8089 |
| **Metadata DB** | PostgreSQL | 14-alpine | 5433 |
| **Coordination** | Zookeeper | 3.7 | 2182 |

---

## 📂 Структура проекта

```
docker/lab6/
├── docker-compose.yml              # Все сервисы Lab 6
├── .gitignore
├── README.md                       # Эта документация
│
├── pinot-configs/                  # Конфигурации Pinot
│   ├── current_prices_schema.json  # Schema для таблицы
│   └── current_prices_table.json   # Table config (Kafka stream)
│
├── superset-configs/               # Конфигурации Superset
│   ├── superset_config.py          # Custom config
│   └── databases.yaml              # Database connections
│
└── scripts/
    ├── start.sh                    # 🚀 All-in-one запуск
    ├── stop.sh                     # Остановка
    ├── setup-pinot.sh              # Настройка Pinot
    ├── setup-superset.sh           # Настройка Superset
    └── test.sh                     # Проверка работоспособности
```

---

## 🚀 Быстрый старт

### Предварительные требования

1. **Labs 1-5 должны быть настроены** (Kafka, Hive, данные должны быть доступны)
2. **Docker и Docker Compose**
3. **Минимум 6 GB RAM для Docker**

### Шаг 1: Проверка prerequisites

Убедитесь, что запущены необходимые сервисы:

```bash
# Kafka (Lab 1-2)
cd docker/kafka
docker-compose ps

# HDFS + Hive (Lab 3)
cd ../lab3
docker-compose ps

# Проверьте что есть данные в Hive
docker exec -it hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root \
  -e "USE moex_data; SELECT COUNT(*) FROM trades;"
```

Должно быть > 0 записей в Hive.

### Шаг 2: Запуск Lab 6 (всё автоматически!)

```bash
cd docker/lab6
./scripts/start.sh
```

**Скрипт `start.sh` автоматически:**
1. ✅ Проверяет prerequisites (Kafka, network)
2. ✅ Запускает все сервисы (Pinot, Superset, PostgreSQL)
3. ✅ Создаёт Pinot таблицу `current_prices`
4. ✅ Настраивает Superset database connections
5. ✅ Устанавливает драйверы (pyhive, pinotdb)

**Время выполнения:** ~3-5 минут

### Шаг 3: Проверка работы

```bash
./scripts/test.sh
```

### Шаг 4: Открыть Superset

Откройте браузер: **http://localhost:8089**

**Логин:** `admin`
**Пароль:** `admin`

---

## 🎨 Создание дашбордов

### Dashboard 1: Batch Analytics (Hive данные)

#### Подключение к данным

1. В Superset перейдите в **SQL Lab**
2. Выберите database: **Apache Hive (Batch Data)**
3. Выберите schema: **moex_data**

#### Примеры SQL запросов

**1. Общая статистика:**
```sql
SELECT
    COUNT(*) as total_trades,
    COUNT(DISTINCT secid) as unique_instruments,
    SUM(value) as total_volume
FROM trades;
```

**2. Топ-10 инструментов по количеству сделок:**
```sql
SELECT
    secid,
    COUNT(*) as trade_count,
    SUM(value) as total_volume
FROM trades
GROUP BY secid
ORDER BY trade_count DESC
LIMIT 10;
```

**3. Распределение BUY vs SELL:**
```sql
SELECT
    buysell,
    COUNT(*) as count,
    SUM(value) as volume
FROM trades
WHERE buysell IN ('B', 'S')
GROUP BY buysell;
```

**4. Почасовые объемы торгов (из MapReduce результатов):**
```sql
SELECT *
FROM trade_volumes_hourly
ORDER BY hour_start DESC
LIMIT 100;
```

**5. Временная динамика сделок:**
```sql
SELECT
    substr(tradetime, 1, 13) as hour,
    COUNT(*) as trade_count
FROM trades
GROUP BY substr(tradetime, 1, 13)
ORDER BY hour;
```

#### Создание визуализаций

1. **Big Number** - Total Trades
   - Metric: `COUNT(*)`
   - Используйте запрос 1

2. **Bar Chart** - Top Instruments
   - Dimension: `secid`
   - Metric: `COUNT(*)` или `SUM(value)`
   - Используйте запрос 2

3. **Pie Chart** - BUY vs SELL
   - Dimension: `buysell`
   - Metric: `COUNT(*)`
   - Используйте запрос 3

4. **Line Chart** - Trade Volume Over Time
   - X-axis: `hour` (temporal)
   - Y-axis: `SUM(value)`
   - Group by: `secid` (для multiple lines)

### Dashboard 2: Real-time Monitoring (Pinot данные)

#### Подключение к данным

1. В Superset перейдите в **SQL Lab**
2. Выберите database: **Apache Pinot (Streaming Data)**
3. Выберите table: **current_prices**

#### Примеры SQL запросов для Pinot

**1. Последние цены по инструментам:**
```sql
SELECT
    secid,
    current_price,
    buy_avg,
    sell_avg,
    timestamp
FROM current_prices
ORDER BY timestamp DESC
LIMIT 20
```

**2. Текущая цена конкретного инструмента:**
```sql
SELECT
    secid,
    current_price,
    timestamp
FROM current_prices
WHERE secid = 'SBER'
ORDER BY timestamp DESC
LIMIT 1
```

**3. Динамика цен за последний час:**
```sql
SELECT
    secid,
    current_price,
    timestamp
FROM current_prices
WHERE timestamp > ago('PT1H')
ORDER BY timestamp
```

**4. Спред BUY/SELL:**
```sql
SELECT
    secid,
    buy_avg,
    sell_avg,
    (buy_avg - sell_avg) as spread,
    timestamp
FROM current_prices
WHERE buy_avg IS NOT NULL AND sell_avg IS NOT NULL
ORDER BY timestamp DESC
LIMIT 50
```

**5. Средняя цена по инструментам:**
```sql
SELECT
    secid,
    AVG(current_price) as avg_price,
    MIN(current_price) as min_price,
    MAX(current_price) as max_price,
    COUNT(*) as data_points
FROM current_prices
GROUP BY secid
```

#### Создание визуализаций

1. **Big Number with Trend** - Current Price
   - Metric: `current_price`
   - Filter: `secid = 'SBER'` (выберите инструмент)
   - **Enable Auto Refresh:** 10 seconds

2. **Time Series Chart** - Price Dynamics
   - X-axis: `timestamp`
   - Y-axis: `current_price`
   - Group by: `secid`
   - **Enable Auto Refresh:** 10 seconds

3. **Dual Line Chart** - BUY vs SELL
   - X-axis: `timestamp`
   - Y-axis: `buy_avg`, `sell_avg`
   - **Enable Auto Refresh:** 10 seconds

4. **Table** - Latest Prices
   - Columns: `secid`, `current_price`, `buy_avg`, `sell_avg`, `timestamp`
   - Order by: `timestamp DESC`
   - **Enable Auto Refresh:** 10 seconds

5. **Heatmap** - Price Activity
   - Rows: `secid`
   - Columns: Time buckets
   - Metric: `COUNT(*)` (интенсивность обновлений)

---

## 🌐 Web UI интерфейсы

| Сервис | URL | Credentials | Описание |
|--------|-----|-------------|----------|
| **Superset** | http://localhost:8089 | admin / admin | Визуализация и дашборды |
| **Pinot Console** | http://localhost:9001 | - | Управление Pinot, выполнение запросов |
| **Kafka UI** | http://localhost:8080 | - | Мониторинг Kafka (из Lab 1-2) |
| **HDFS NameNode** | http://localhost:9870 | - | Статус HDFS (из Lab 3) |
| **YARN** | http://localhost:8088 | - | Статус YARN (из Lab 4) |
| **Spark Master** | http://localhost:8083 | - | Статус Spark (из Lab 5) |
| **NiFi** | http://localhost:8082/nifi | admin / adminadminadmin | Dataflow (из Lab 3) |

---

## 🔧 Управление инфраструктурой

### Просмотр логов

```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f pinot-controller
docker-compose logs -f superset
```

### Перезапуск сервиса

```bash
docker-compose restart pinot-controller
docker-compose restart superset
```

### Остановка всех сервисов

```bash
./scripts/stop.sh

# Или с удалением данных
docker-compose down -v
```

### Очистка Pinot таблиц

```bash
# Удалить таблицу
curl -X DELETE http://localhost:9001/tables/current_prices

# Пересоздать
./scripts/setup-pinot.sh
```

---

## 🧪 Тестирование

### Комплексная проверка

```bash
./scripts/test.sh
```

Скрипт проверит:
- ✅ Pinot Controller health
- ✅ Pinot Broker health
- ✅ Наличие таблицы `current_prices`
- ✅ Выполнение SQL запросов к Pinot
- ✅ Superset health
- ✅ Superset PostgreSQL
- ✅ Kafka topic `moex.current_prices`
- ✅ Все Docker контейнеры запущены

### Ручная проверка Pinot

```bash
# Проверка health
curl http://localhost:9001/health

# Список таблиц
curl http://localhost:9001/tables

# Выполнить SQL запрос
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM current_prices LIMIT 10"}' \
  http://localhost:8099/query/sql
```

### Ручная проверка Superset

```bash
# Health check
curl http://localhost:8089/health

# Список databases (требует авторизацию)
curl -u admin:admin http://localhost:8089/api/v1/database/
```

---

## 📊 Источники данных

### 1. Apache Hive (Batch Data)

**Connection String:** `hive://hive:10000/moex_data`

**Доступные таблицы:**

| Таблица | Описание | Источник |
|---------|----------|----------|
| `trades` | Все сделки с биржи | Lab 3 (NiFi → Hive) |
| `trade_volumes_hourly` | Почасовые объемы торгов | Lab 4 (MapReduce) |

**Схема `trades`:**
```
tradeno BIGINT
tradetime STRING
secid STRING
boardid STRING
price DOUBLE
quantity BIGINT
value DOUBLE
buysell STRING
period STRING
tradingsession STRING
systime STRING
ts_offset BIGINT
```

**Схема `trade_volumes_hourly`:**
```
secid STRING
hour_start STRING
hour_end STRING
total_volume DOUBLE
```

### 2. Apache Pinot (Streaming Data)

**Connection String:** `pinot://pinot-broker:8099/query?controller=http://pinot-controller:9001/`

**Доступные таблицы:**

| Таблица | Описание | Источник |
|---------|----------|----------|
| `current_prices` | Текущие цены активов в реальном времени | Lab 5 (Spark Streaming → Kafka → Pinot) |

**Схема `current_prices`:**
```
secid STRING            -- Код инструмента (SBER, GAZP, ...)
current_price DOUBLE    -- Текущая цена (среднее BUY и SELL)
buy_avg DOUBLE          -- Средняя взвешенная цена BUY
sell_avg DOUBLE         -- Средняя взвешенная цена SELL
timestamp LONG          -- Время расчёта (milliseconds)
window_start STRING     -- Начало временного окна
window_end STRING       -- Конец временного окна
```

---

## ❗ Troubleshooting

### Проблема: Pinot Controller не запускается

**Симптомы:**
```
curl: (7) Failed to connect to localhost port 9001
```

**Решение:**
1. Проверить логи:
   ```bash
   docker logs pinot-controller
   ```
2. Убедиться что Zookeeper запущен:
   ```bash
   docker ps | grep pinot-zookeeper
   ```
3. Перезапустить:
   ```bash
   docker-compose restart pinot-zookeeper pinot-controller
   ```

### Проблема: Pinot не может прочитать из Kafka

**Симптомы:**
```
SELECT COUNT(*) FROM current_prices;
-- Result: 0 rows
```

**Чек-лист:**
1. ✅ Kafka запущен:
   ```bash
   docker ps | grep moex-kafka
   ```
2. ✅ Топик `moex.current_prices` существует:
   ```bash
   docker exec moex-kafka kafka-topics --list --bootstrap-server localhost:9092 | grep current_prices
   ```
3. ✅ Есть данные в топике:
   ```bash
   docker exec moex-kafka kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic moex.current_prices \
     --max-messages 5
   ```
4. ✅ Spark Streaming job (Lab 5) запущен:
   ```bash
   curl http://localhost:8083/json/ | jq '.activeapps'
   ```

### Проблема: Superset не может подключиться к Hive

**Симптомы:**
```
Connection failed: Could not connect to hive
```

**Решение:**
1. Проверить что HiveServer2 запущен:
   ```bash
   docker ps | grep hive-server
   ```
2. Проверить доступность Hive:
   ```bash
   docker exec -it hive-server /opt/hive/bin/beeline \
     -u jdbc:hive2://localhost:10000 \
     -n root \
     -e "SHOW DATABASES;"
   ```
3. Переустановить драйвер:
   ```bash
   docker exec superset pip install --upgrade pyhive[hive] thrift thrift-sasl
   docker-compose restart superset
   ```

### Проблема: Superset не может подключиться к Pinot

**Симптомы:**
```
Connection failed: Could not connect to pinot
```

**Решение:**
1. Проверить Pinot Broker:
   ```bash
   curl http://localhost:8099/health
   ```
2. Переустановить драйвер:
   ```bash
   docker exec superset pip install --upgrade pinotdb
   docker-compose restart superset
   ```
3. Проверить connection string:
   ```
   pinot://pinot-broker:8099/query?controller=http://pinot-controller:9001/
   ```

### Проблема: Superset admin пользователь не создан

**Решение:**
```bash
docker exec -it superset superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@superset.com \
  --password admin
```

### Проблема: Out of Memory

**Решение:** Увеличить память для Docker (минимум 6 GB)

**macOS/Windows:**
- Docker Desktop → Settings → Resources → Memory → 8 GB

**Linux:**
- Убедитесь что достаточно RAM

---

## 📚 Полезные команды

### Pinot

```bash
# Список таблиц
curl http://localhost:9001/tables | jq

# Информация о таблице
curl http://localhost:9001/tables/current_prices | jq

# Удалить таблицу
curl -X DELETE http://localhost:9001/tables/current_prices

# SQL запрос
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT COUNT(*) FROM current_prices"}' \
  http://localhost:8099/query/sql | jq
```

### Superset

```bash
# Создать admin пользователя
docker exec superset superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@superset.com \
  --password admin

# Database upgrade
docker exec superset superset db upgrade

# Init Superset
docker exec superset superset init

# Список users
docker exec superset superset fab list-users
```

### PostgreSQL (Superset metadata)

```bash
# Подключиться к БД
docker exec -it superset-db psql -U superset -d superset

# Список таблиц
docker exec superset-db psql -U superset -d superset -c "\dt"

# Посмотреть databases
docker exec superset-db psql -U superset -d superset -c "SELECT * FROM dbs;"
```

---

## 🎯 Следующие шаги

После успешного завершения Lab 6:

- ✅ Данные визуализированы в интерактивных дашбордах
- ✅ Реализован полный pipeline: Сбор → Хранение → Обработка → Визуализация
- ✅ Поддержка batch (Hive) и streaming (Pinot) аналитики
- ✅ Real-time мониторинг цен активов

**Готовый проект для демонстрации!** 🎉

---

## 📖 Дополнительные ресурсы

- [Apache Pinot Documentation](https://docs.pinot.apache.org/)
- [Apache Superset Documentation](https://superset.apache.org/docs/intro)
- [Pinot SQL Reference](https://docs.pinot.apache.org/users/user-guide-query/querying-pinot)
- [Superset Chart Types](https://superset.apache.org/docs/configuration/configuring-superset)

---

## 👥 Авторы

Студенты МИФИ, курс "Технологии обработки больших данных"

---

## 📝 Полный Pipeline проекта

```
┌──────────────────────────────────────────────────────────────┐
│                    MOEX Data Pipeline                        │
└──────────────────────────────────────────────────────────────┘

Lab 1-2: Data Collection
  ├─ MOEX API → Kotlin Collector → Kafka
  └─ Topics: moex.trades, moex.instruments

Lab 3: Data Storage
  ├─ Kafka → NiFi → HDFS
  └─ HDFS → Hive tables (moex_data.trades)

Lab 4: Batch Processing
  ├─ Hive → MapReduce (Hadoop YARN)
  └─ Output: trade_volumes_hourly

Lab 5: Stream Processing
  ├─ Kafka → Spark Streaming
  └─ Output: moex.current_prices (Kafka)

Lab 6: Visualization ⭐
  ├─ Hive (batch) → Superset Dashboards
  ├─ Kafka → Pinot (real-time) → Superset Dashboards
  └─ Interactive dashboards with auto-refresh

🎉 Complete Big Data Pipeline!
```
