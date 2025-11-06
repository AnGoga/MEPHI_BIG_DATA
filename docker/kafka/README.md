# Kafka Infrastructure

Этот Docker Compose файл запускает инфраструктуру Kafka для проекта MOEX Data Collector.

## Компоненты

- **Zookeeper** - координация Kafka кластера (порт 2181)
- **Kafka** - брокер сообщений (порты 9092, 9093)
- **Kafka UI** - веб-интерфейс для мониторинга Kafka (порт 8080)
- **Kafka Init** - инициализация топиков

## Запуск

```bash
# Запустить все сервисы
docker-compose up -d

# Посмотреть логи
docker-compose logs -f

# Остановить сервисы
docker-compose down

# Остановить и удалить данные
docker-compose down -v
```

## Топики

Автоматически создаются следующие топики:

- `moex.trades` - данные о сделках (3 партиции)
- `moex.instruments` - информация о торговых инструментах (1 партиция)

## Доступ

- **Kafka Broker**: `localhost:9092`
- **Kafka UI**: http://localhost:8080
- **Zookeeper**: `localhost:2181`

## Проверка работоспособности

### Просмотр топиков

```bash
docker exec -it moex-kafka kafka-topics --list --bootstrap-server localhost:9092
```

### Просмотр сообщений в топике

```bash
# Trades
docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.trades \
  --from-beginning

# Instruments
docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.instruments \
  --from-beginning
```

### Отправка тестового сообщения

```bash
docker exec -it moex-kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic moex.trades
```

## Мониторинг через Kafka UI

Откройте в браузере: http://localhost:8080

Вы увидите:
- Список топиков
- Количество сообщений
- Партиции
- Consumer groups
- И многое другое
