# Быстрый старт

## Лабораторная работа №1-2: Сбор данных и Kafka

### Шаг 1: Запустить Kafka

```bash
./start-kafka.sh
```

Откройте Kafka UI в браузере: http://localhost:8080

### Шаг 2: Настроить тикеры (опционально)

Отредактируйте `moex-collector/src/main/resources/tickers.yml`:

```yaml
tickers:
  mode: SPECIFIC  # или ALL
  symbols:
    - SBER
    - GAZP
    - LKOH
```

### Шаг 3: Запустить коллектор

```bash
./run-collector.sh
```

### Шаг 4: Просмотреть данные

#### Вариант A: Через Kafka UI (рекомендуется)

Откройте http://localhost:8080 → Topics → moex.trades

#### Вариант B: Через консоль

```bash
./view-trades.sh
```

#### Вариант C: Через consumer

```bash
docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.trades \
  --from-beginning
```

### Остановить Kafka

```bash
./stop-kafka.sh
```

### Сбросить курсор (перезагрузить все данные)

```bash
# Удалить курсор и перезапустить Initial Load
./reset-cursor.sh

# Затем запустить collector заново
./run-collector.sh
```

## Режимы работы

### Initial Load (первый запуск)

При первом запуске коллектор автоматически:
1. Загружает **ВСЕ** сделки с начала торгового дня (00:00:00)
2. Использует автоматическую пагинацию (по 5000 сделок)
3. Сохраняет прогресс в `data/collection-cursor.json`
4. Переходит в режим Incremental Load

**Время:** ~5-10 минут (зависит от времени суток)
**Данных:** от 50,000 до 200,000 сделок

### Incremental Load (нормальный режим)

После Initial Load:
1. Каждые 3 секунды загружает новые сделки
2. Использует временные фильтры (от lastTradeTime до now)
3. Гарантирует 0 пропусков (даже если >5000 сделок за интервал)
4. Сохраняет прогресс после каждого цикла

**Результат:** Непрерывный поток данных в реальном времени без пропусков!

### Перезапуск после остановки

```bash
# Остановить (Ctrl+C)
# Запустить снова
./run-collector.sh

# ✅ Initial Load НЕ выполнится (уже завершен)
# ✅ Продолжится с lastTradeTime из курсора
```

## Полезные команды

### Просмотр логов Kafka

```bash
cd docker/kafka
docker-compose logs -f kafka
```

### Список топиков

```bash
docker exec -it moex-kafka kafka-topics --list --bootstrap-server localhost:9092
```

### Информация о топике

```bash
docker exec -it moex-kafka kafka-topics \
  --describe \
  --topic moex.trades \
  --bootstrap-server localhost:9092
```

### Количество сообщений в топике

```bash
docker exec -it moex-kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic moex.trades \
  --time -1
```

### Сборка проекта без запуска

```bash
cd moex-collector
./gradlew build
```

### Запуск тестов

```bash
cd moex-collector
./gradlew test
```

## Структура данных

### Trade (сделка)

```json
{
  "tradeno": 1234567890,
  "tradetime": "2024-01-15 10:30:45",
  "secid": "SBER",
  "boardid": "TQBR",
  "price": 258.50,
  "quantity": 100,
  "value": 25850.00,
  "buysell": "B",
  "systime": "2024-01-15 10:30:45.123",
  "timestamp": 1705315845000
}
```

### Security (инструмент)

```json
{
  "secid": "SBER",
  "boardid": "TQBR",
  "shortname": "Сбербанк",
  "secname": "Сбербанк России ПАО ао",
  "prevprice": 257.80,
  "lotsize": 10,
  "currencyid": "RUB"
}
```

## Конфигурация

### Основные параметры (application.yml)

- `moex.api.rate-limit-ms: 1000` - ограничение частоты запросов к API
- `moex.collector.interval-ms: 5000` - интервал сбора данных
- `moex.collector.enabled: true` - включить/выключить сборщик

### Переменные среды

```bash
# Адрес Kafka
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# Запуск
./run-collector.sh
```

## Troubleshooting

### Kafka не запускается

```bash
# Остановить и удалить данные
cd docker/kafka
docker-compose down -v

# Запустить заново
docker-compose up -d
```

### Нет данных в топике

1. Проверить логи приложения
2. Проверить конфигурацию tickers.yml
3. Проверить доступность MOEX API:
   ```bash
   curl https://iss.moex.com/iss/engines/stock/markets/shares/trades.json?limit=1
   ```

### Приложение не подключается к Kafka

1. Проверить что Kafka запущен: `docker ps`
2. Проверить логи Kafka: `docker-compose logs kafka`
3. Проверить порт 9092: `netstat -an | grep 9092`

## Следующие шаги

После завершения лабораторных №1-2:

- [ ] Лаборатория №3: HDFS + Hive + NiFi
- [ ] Лаборатория №4: MapReduce
- [ ] Лаборатория №5: Spark Streaming
- [ ] Лаборатория №6: Superset + Pinot
