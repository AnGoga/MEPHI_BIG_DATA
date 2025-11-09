# Лабораторная работа №5: Потоковая обработка данных

**Цель**: В реальном времени считать текущую цену актива - среднее значение `(quantity * price)` между сделками **BUY** и **SELL** по каждому инструменту, используя Apache Spark Streaming.

---

## 📊 Архитектура решения

```
┌─────────────────────────────────────────────────────────┐
│                    INPUT STREAM                          │
│  Kafka Topic: moex.trades                               │
│  {tradeno, tradetime, secid, price, quantity, buysell}  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│            Apache Spark Structured Streaming             │
│                                                           │
│  1. Read from Kafka (moex.trades)                        │
│  2. Parse JSON                                           │
│  3. Filter: buysell IN ('B', 'S')                       │
│  4. Calculate weighted_price = price * quantity          │
│  5. Group by: window(10s, slide 5s), secid, buysell     │
│  6. Aggregate: avg(weighted_price)                       │
│  7. Pivot BUY/SELL into columns                          │
│  8. Calculate: current_price = (buy_avg + sell_avg) / 2 │
│  9. Write to Kafka (moex.current_prices)                │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│                    OUTPUT STREAM                         │
│  Kafka Topic: moex.current_prices                       │
│  {secid, current_price, buy_avg, sell_avg, timestamp}   │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠️ Технологический стек

| Компонент | Технология | Версия |
|-----------|-----------|--------|
| **Streaming Engine** | Apache Spark | 3.5.0 |
| **Язык** | Kotlin | 1.9.22 |
| **Сборка** | Gradle | 8.5 |
| **Брокер** | Apache Kafka | 7.5.1 |
| **Формат** | JSON | - |

---

## 📂 Структура проекта

```
lab5/
├── docker-compose.yml          # Spark Master + Worker
├── .gitignore
├── README.md                   # Эта документация
│
├── spark-streaming/            # Kotlin приложение
│   ├── build.gradle.kts
│   ├── settings.gradle.kts
│   ├── gradlew
│   └── src/main/kotlin/
│       └── ru/mephi/moex/streaming/
│           ├── MoexCurrentPriceCalculator.kt  # Главный класс
│           └── model/
│               ├── Trade.kt                   # Модель входных данных
│               └── CurrentPrice.kt            # Модель выходных данных
│
└── scripts/
    ├── start.sh                # Запуск Spark кластера
    ├── stop.sh                 # Остановка
    ├── build-app.sh            # Сборка Kotlin приложения
    ├── submit-job.sh           # Отправка Spark job
    ├── view-current-prices.sh  # Просмотр результатов
    └── test.sh                 # Тестирование пайплайна
```

---

## 🚀 Быстрый старт

### Предварительные требования

- JDK 11 или выше
- Docker и Docker Compose
- Запущенный Kafka (из `docker/kafka`)
- Запущенный MOEX Collector (генерирует данные)

### Шаг 1: Запустить Kafka (если еще не запущен)

```bash
cd docker/kafka
docker-compose up -d
cd ../..
```

### Шаг 2: Запустить MOEX Collector (генерация данных)

```bash
cd moex-collector
./gradlew bootRun &
cd ..
```

Подождите 30 секунд, чтобы данные начали поступать в Kafka.

### Шаг 3: Запустить Spark кластер

```bash
cd lab5
./scripts/start.sh
```

Проверьте Spark Master UI: http://localhost:8083

### Шаг 4: Собрать приложение

```bash
./scripts/build-app.sh
```

JAR будет создан в: `spark-streaming/build/libs/moex-streaming-1.0.0-all.jar`

### Шаг 5: Запустить Spark Streaming job

```bash
./scripts/submit-job.sh
```

Приложение начнёт обрабатывать данные из Kafka и писать результаты обратно в Kafka.

### Шаг 6: Просмотр результатов

```bash
./scripts/view-current-prices.sh
```

Вы увидите JSON сообщения с текущими ценами для каждого инструмента.

### Шаг 7: Тестирование

```bash
./scripts/test.sh
```

---

## 🔍 Как это работает

### 1. Чтение из Kafka

Spark Streaming подключается к топику `moex.trades` и читает JSON сообщения:

```json
{
  "tradeno": 1234567,
  "tradetime": "2024-01-15 10:00:00",
  "secid": "SBER",
  "price": 258.5,
  "quantity": 100,
  "buysell": "B"
}
```

### 2. Фильтрация валидных сделок

Оставляем только сделки где `buysell` = "B" (BUY) или "S" (SELL).

### 3. Вычисление взвешенной цены

Добавляем колонку: `weighted_price = price * quantity`

**Пример:**
- Сделка: 100 акций по 258.5₽ → weighted = 25,850
- Сделка: 50 акций по 259.0₽ → weighted = 12,950

### 4. Группировка по временным окнам

Используем **sliding windows**:
- **Window size**: 10 секунд
- **Slide**: 5 секунд (перекрывающиеся окна)
- **Watermark**: 30 секунд (ждём опоздавшие данные)

```
Время:    10:00  10:05  10:10  10:15  10:20
          │      │      │      │      │
Окно 1:   [──────────────]               (10:00-10:10)
Окно 2:         [──────────────]         (10:05-10:15)
Окно 3:                [──────────────]  (10:10-10:20)
```

Группируем по: `window`, `secid`, `buysell` и считаем `avg(weighted_price)`.

### 5. Pivot BUY/SELL

Разворачиваем строки с BUY и SELL в отдельные колонки:

**До pivot:**
```
window          | secid | buysell | avg_weighted_price
[10:00-10:10]   | SBER  | B       | 25800.0
[10:00-10:10]   | SBER  | S       | 13000.0
```

**После pivot:**
```
window          | secid | buy_avg | sell_avg
[10:00-10:10]   | SBER  | 25800.0 | 13000.0
```

### 6. Расчёт текущей цены

**Формула:**
```kotlin
current_price = when {
    buy_avg != null && sell_avg != null -> (buy_avg + sell_avg) / 2
    buy_avg != null -> buy_avg
    sell_avg != null -> sell_avg
    else -> null
}
```

**Пример:**
- `buy_avg` = 25,800
- `sell_avg` = 13,000
- `current_price` = (25,800 + 13,000) / 2 = **19,400**

### 7. Запись в Kafka

Результат отправляется в топик `moex.current_prices`:

```json
{
  "secid": "SBER",
  "current_price": 19400.0,
  "buy_avg": 25800.0,
  "sell_avg": 13000.0,
  "timestamp": "2024-01-15T10:10:05.123Z",
  "window_start": "2024-01-15 10:00:00",
  "window_end": "2024-01-15 10:10:00"
}
```

---

## 📊 Формат выходных данных

### Топик Kafka: `moex.current_prices`

**Key:** `{secid}` (например, "SBER")

**Value (JSON):**
```json
{
  "secid": "SBER",
  "current_price": 19400.0,
  "buy_avg": 25800.0,
  "sell_avg": 13000.0,
  "timestamp": "2024-01-15T10:10:05.123Z",
  "window_start": "2024-01-15 10:00:00",
  "window_end": "2024-01-15 10:10:00"
}
```

**Поля:**
- `secid` - код инструмента (SBER, GAZP, и т.д.)
- `current_price` - текущая цена (среднее между BUY и SELL)
- `buy_avg` - средняя взвешенная цена по BUY сделкам
- `sell_avg` - средняя взвешенная цена по SELL сделкам
- `timestamp` - время расчёта
- `window_start` - начало временного окна
- `window_end` - конец временного окна

---

## 🌐 Web UI интерфейсы

| Сервис | URL | Описание |
|--------|-----|----------|
| **Spark Master** | http://localhost:8083 | Статус кластера, Workers, приложения |
| **Spark Application** | http://localhost:4040 | Streaming metrics (когда job запущен) |
| **Kafka UI** | http://localhost:8080 | Мониторинг Kafka топиков |

---

## 🔧 Управление инфраструктурой

### Просмотр логов

```bash
# Spark Master
docker logs -f moex-spark-master

# Spark Worker
docker logs -f moex-spark-worker-1

# Все сервисы
docker-compose logs -f
```

### Перезапуск сервисов

```bash
docker-compose restart spark-master
docker-compose restart spark-worker-1
```

### Остановка

```bash
./scripts/stop.sh

# Или с удалением данных
docker-compose down -v
```

---

## 🧪 Тестирование

### Проверка данных в Kafka

**Входной топик (moex.trades):**
```bash
docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.trades \
  --max-messages 10
```

**Выходной топик (moex.current_prices):**
```bash
./scripts/view-current-prices.sh
```

### Проверка Spark кластера

```bash
# Статус кластера
curl http://localhost:8083/json/ | jq

# Активные приложения
curl http://localhost:8083/json/ | jq '.activeapps'

# Подключённые workers
curl http://localhost:8083/json/ | jq '.aliveworkers'
```

### Комплексная проверка

```bash
./scripts/test.sh
```

---

## 📈 Производительность

### Типичные характеристики

- **Latency**: 5-10 секунд (end-to-end)
- **Throughput**: 1000-5000 сделок/сек
- **Memory**: ~2GB per Worker
- **CPU**: 2 cores per Worker

### Настройка производительности

**Увеличить параллелизм:**
```bash
# В submit-job.sh изменить:
--conf spark.sql.shuffle.partitions=10  # было 3
```

**Добавить второй Worker:**
```yaml
# В docker-compose.yml раскомментировать spark-worker-2
```

**Уменьшить latency:**
```kotlin
// В MoexCurrentPriceCalculator.kt изменить:
.trigger(Trigger.ProcessingTime("2 seconds"))  // было 5 секунд
```

---

## ❗ Troubleshooting

### Проблема: Spark Worker не подключается к Master

**Симптомы:**
```
curl http://localhost:8083/json/ | jq '.aliveworkers'
# Результат: 0
```

**Решение:**
1. Проверить логи Worker:
   ```bash
   docker logs moex-spark-worker-1
   ```
2. Перезапустить Worker:
   ```bash
   docker-compose restart spark-worker-1
   ```

### Проблема: Нет данных в moex.current_prices

**Чек-лист:**
1. ✅ Kafka работает:
   ```bash
   docker ps | grep moex-kafka
   ```
2. ✅ Есть данные в moex.trades:
   ```bash
   docker exec moex-kafka kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic moex.trades \
     --max-messages 10
   ```
3. ✅ MOEX Collector запущен:
   ```bash
   ps aux | grep gradlew
   ```
4. ✅ Spark job запущен:
   ```bash
   curl http://localhost:8083/json/ | jq '.activeapps'
   ```

### Проблема: Out of Memory

**Решение:**
```bash
# Увеличить память Worker в docker-compose.yml:
SPARK_WORKER_MEMORY=4G  # было 2G
```

### Проблема: JAR не найден при submit

**Решение:**
```bash
# Пересобрать приложение
./scripts/build-app.sh

# Проверить что JAR существует
ls -lh spark-streaming/build/libs/moex-streaming-1.0.0-all.jar
```

---

## 📚 Полезные команды

### Kafka

```bash
# Создать топик вручную
docker exec moex-kafka kafka-topics \
  --create \
  --bootstrap-server localhost:9092 \
  --topic moex.current_prices \
  --partitions 3 \
  --replication-factor 1

# Удалить топик
docker exec moex-kafka kafka-topics \
  --delete \
  --bootstrap-server localhost:9092 \
  --topic moex.current_prices

# Количество сообщений в топике
docker exec moex-kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic moex.current_prices
```

### Spark

```bash
# Убить запущенное приложение
docker exec moex-spark-master \
  /opt/bitnami/spark/bin/spark-class org.apache.spark.deploy.Client \
  kill spark://spark-master:7077 <APP_ID>

# Список приложений
curl http://localhost:8083/api/v1/applications
```

---

## 🎯 Следующие шаги

После успешного завершения Lab 5:

- ✅ Данные обрабатываются в реальном времени
- ✅ Текущие цены считаются корректно
- ✅ Результаты доступны в Kafka

**Следующая лаборатория (Lab 6)**: Визуализация данных с Apache Pinot и Superset.

---

## 📖 Дополнительные ресурсы

- [Apache Spark Structured Streaming](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [Spark + Kafka Integration](https://spark.apache.org/docs/latest/structured-streaming-kafka-integration.html)
- [Kotlin for Apache Spark](https://kotlinlang.org/)
- [Bitnami Spark Docker](https://github.com/bitnami/containers/tree/main/bitnami/spark)

---

## 👥 Авторы

Студенты МИФИ, курс "Технологии обработки больших данных"
