# MEPHI Big Data - MOEX Data Pipeline

Учебный проект по обработке больших данных с использованием биржевых данных Московской Биржи (MOEX).

## Описание проекта

Проект состоит из нескольких лабораторных работ, охватывающих полный цикл работы с большими данными:

1. **Лаборатория 1-2**: Сбор данных и интеграция с Apache Kafka
2. **Лаборатория 3**: Хранение данных (HDFS, Apache Hive, Apache NiFi)
3. **Лаборатория 4**: Пакетная обработка (Apache Hadoop MapReduce)
4. **Лаборатория 5**: Потоковая обработка (Apache Spark Streaming)
5. **Лаборатория 6**: Визуализация данных (Apache Pinot, Apache Superset)

## Текущий статус: Лаборатория 1-2 ✅

### Технологии

- **Язык**: Kotlin 1.9.22
- **Фреймворк**: Spring Boot 3.2.1
- **Сборка**: Gradle 8.5
- **Брокер сообщений**: Apache Kafka 7.5.1
- **Формат данных**: JSON

## Структура проекта

```
MEPHI_BIG_DATA/
├── moex-collector/          # Сервис сбора данных с MOEX API
│   ├── src/
│   │   └── main/
│   │       ├── kotlin/
│   │       │   └── ru/mephi/moex/collector/
│   │       │       ├── client/        # HTTP клиент для MOEX API
│   │       │       ├── config/        # Конфигурация приложения
│   │       │       ├── model/         # Модели данных
│   │       │       └── service/       # Бизнес-логика
│   │       └── resources/
│   │           ├── application.yml    # Основная конфигурация
│   │           └── tickers.yml        # Конфигурация тикеров
│   └── build.gradle.kts
├── docker/
│   └── kafka/                # Docker Compose для Kafka
│       ├── docker-compose.yml
│       └── README.md
└── README.md
```

## Быстрый старт

### Предварительные требования

- JDK 17 или выше
- Docker и Docker Compose
- Gradle 8.5+ (опционально, можно использовать wrapper)

### 1. Запуск Kafka

```bash
cd docker/kafka
docker-compose up -d
```

Проверьте доступность Kafka UI: http://localhost:8080

### 2. Конфигурация тикеров

Отредактируйте файл `moex-collector/src/main/resources/tickers.yml`:

```yaml
tickers:
  mode: SPECIFIC  # или ALL для всех инструментов
  symbols:
    - SBER
    - GAZP
    - LKOH
```

### 3. Сборка и запуск приложения

```bash
cd moex-collector

# Сборка
./gradlew build

# Запуск
./gradlew bootRun
```

### 4. Просмотр данных

#### Через Kafka UI
Откройте http://localhost:8080 и выберите топик `moex.trades`

#### Через консольный consumer

```bash
docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.trades \
  --from-beginning
```

## Конфигурация

### application.yml

Основные параметры конфигурации:

- `moex.api.base-url` - базовый URL MOEX API
- `moex.api.rate-limit-ms` - ограничение частоты запросов (мс)
- `moex.collector.interval-ms` - интервал сбора данных (мс)
- `moex.collector.engine` - торговая система (stock, currency, etc.)
- `moex.collector.market` - рынок (shares, bonds, etc.)

### tickers.yml

Конфигурация отслеживаемых инструментов:

```yaml
# Режим SPECIFIC - конкретные тикеры
tickers:
  mode: SPECIFIC
  symbols:
    - SBER
    - GAZP

# Режим ALL - все доступные инструменты
tickers:
  mode: ALL
```

### Переменные среды

Можно переопределить конфигурацию через переменные среды:

```bash
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
./gradlew bootRun
```

## Архитектура решения

### Компоненты

1. **MoexApiClient** - HTTP клиент для работы с MOEX ISS API
   - Rate limiting (1 запрос/сек)
   - Обработка ошибок
   - Парсинг JSON ответов

2. **TradeDeduplicationService** - предотвращение дубликатов
   - Хранение ID обработанных сделок
   - Автоматическая очистка старых записей

3. **KafkaProducerService** - отправка данных в Kafka
   - Асинхронная отправка
   - Логирование успехов/ошибок

4. **MoexCollectorService** - основной сервис сбора данных
   - Периодический запуск по расписанию
   - Поддержка режимов ALL/SPECIFIC
   - Координация всех компонентов

### Потоки данных

```
MOEX API → MoexApiClient → TradeDeduplicationService → KafkaProducerService → Kafka
                                                                                 ↓
                                                                          moex.trades topic
```

## Топики Kafka

- **moex.trades** - данные о сделках (3 партиции)
  - Key: `{securityId}:{tradeNo}`
  - Value: JSON с информацией о сделке

- **moex.instruments** - информация о торговых инструментах (1 партиция)
  - Key: `{securityId}`
  - Value: JSON с информацией об инструменте

## Модель данных

### Trade

```json
{
  "tradeno": 1234567,
  "tradetime": "2024-01-15 10:30:45",
  "secid": "SBER",
  "boardid": "TQBR",
  "price": 258.50,
  "quantity": 100,
  "value": 25850.00,
  "buysell": "B"
}
```

### Security

```json
{
  "secid": "SBER",
  "boardid": "TQBR",
  "shortname": "Сбербанк",
  "secname": "Сбербанк России ПАО ао",
  "prevprice": 257.80,
  "lotsize": 10
}
```

## Мониторинг и отладка

### Логи приложения

```bash
# Изменить уровень логирования в application.yml
logging:
  level:
    ru.mephi.moex: DEBUG
```

### Метрики

```bash
# Статистика обработанных сделок хранится в TradeDeduplicationService
# Доступна через метод getStats()
```

### Проблемы и решения

#### Kafka не запускается

```bash
# Проверить логи
docker-compose logs kafka

# Перезапустить с очисткой
docker-compose down -v
docker-compose up -d
```

#### Нет данных в топике

1. Проверить логи приложения
2. Проверить конфигурацию tickers.yml
3. Убедиться что MOEX API доступен

## API MOEX

### Документация

- Официальная документация: https://iss.moex.com/iss/reference/
- Примеры запросов в классе `MoexApiClient`

### Основные эндпоинты

```
# Список инструментов
GET https://iss.moex.com/iss/engines/stock/markets/shares/securities.json

# Все сделки
GET https://iss.moex.com/iss/engines/stock/markets/shares/trades.json?reversed=1

# Сделки по инструменту
GET https://iss.moex.com/iss/engines/stock/markets/shares/securities/{SECID}/trades.json
```

## Следующие шаги

- [ ] Лаборатория 3: Настройка HDFS, Hive, NiFi
- [ ] Лаборатория 4: Разработка MapReduce заданий
- [ ] Лаборатория 5: Spark Streaming для обработки в реальном времени
- [ ] Лаборатория 6: Визуализация в Apache Superset

## Лицензия

Учебный проект для МИФИ

## Авторы

Студенты МИФИ, курс "Технологии обработки больших данных"
