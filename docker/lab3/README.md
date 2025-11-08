# Лабораторная работа №3: Хранение данных

**Цель**: Использовать Apache Hive для хранения данных. Для передачи данных из Kafka в Hive использовать Apache NiFi.

---

## Архитектура решения

```
┌─────────────┐
│ MOEX        │
│ Collector   │ ← Сбор данных с биржи
│ (Kotlin)    │
└──────┬──────┘
       │
       ↓
┌─────────────┐
│   Kafka     │ ← Брокер сообщений (Лаба 1-2)
│ moex.trades │
└──────┬──────┘
       │
       ↓
┌─────────────┐
│ Apache NiFi │ ← Dataflow оркестрация (Лаба 3)
│  ConsumeKafka
│      ↓
│  PutHDFS    │
└──────┬──────┘
       │
       ↓
┌─────────────┐
│ Apache Hive │ ← SQL-хранилище данных (Лаба 3)
│ moex_data   │
│  └─ trades  │
└──────┬──────┘
       │
       ↓
┌─────────────┐
│    HDFS     │ ← Распределенная файловая система
│ (Hadoop)    │
└─────────────┘
```

---

## Компоненты

| Компонент | Образ | Порты | Описание |
|-----------|-------|-------|----------|
| **PostgreSQL** | `postgres:15-alpine` | 5432 | Metastore для Hive |
| **Hadoop NameNode** | `bde2020/hadoop-namenode` | 9870, 9000 | HDFS управление |
| **Hadoop DataNode** | `bde2020/hadoop-datanode` | 9864 | HDFS хранилище |
| **Hive** | `bde2020/hive:2.3.2` | 10000, 9083 | SQL интерфейс + Metastore |
| **NiFi** | `apache/nifi:1.23.2` | 8082 | Dataflow управление |

**Важно**: Используются проверенные образы **bde2020** - они настроены для работы "из коробки" с минимальной конфигурацией.

---

## Быстрый старт

### Предварительные требования

- Docker 20.10+
- Docker Compose 1.29+
- Минимум 4 GB RAM для Docker
- Запущенный Kafka (из `docker/kafka`)

### 1. Запуск Kafka (если еще не запущен)

```bash
cd ../kafka
docker-compose up -d
cd ../lab3
```

### 2. Запуск Lab 3 инфраструктуры

**Один скрипт делает всё:**

```bash
./scripts/start.sh
```

Скрипт автоматически:
- ✅ Создает Docker сеть `moex-network`
- ✅ Запускает все контейнеры
- ✅ Инициализирует HDFS директории
- ✅ Настраивает Hive Metastore
- ✅ Создает базу данных `moex_data`
- ✅ Создает таблицу `trades`

**Время запуска**: ~2-3 минуты при первом запуске (скачивание образов).

### 3. Проверка работы

```bash
./scripts/test.sh
```

---

## Настройка NiFi Dataflow

После запуска инфраструктуры нужно настроить поток данных в NiFi.

### Шаг 1: Открыть NiFi UI

Откройте браузер: **http://localhost:8082/nifi**

**Логин**: `admin`
**Пароль**: `adminadminadmin`

### Шаг 2: Создать процессоры

Перетащите на canvas следующие процессоры:

#### Процессор 1: ConsumeKafka_2_6

**Настройки**:
- **Kafka Brokers**: `kafka:29092`
- **Topic Name(s)**: `moex.trades`
- **Group ID**: `nifi-hive-consumer`
- **Offset Reset**: `earliest` (для загрузки всех данных)
- **Key Format**: `String`
- **Value Format**: `String`
- **Message Demarcator**: оставить пустым

**Auto Terminate Relationships**:
- ☑ `success` - НЕ отмечать!
- ☑ `failure` - отметить

#### Процессор 2: PutHDFS

**Настройки**:
- **Hadoop Configuration Resources**: `/opt/hadoop/etc/hadoop/core-site.xml,/opt/hadoop/etc/hadoop/hdfs-site.xml`
- **Directory**: `/user/hive/warehouse/moex_data.db/trades`
- **Conflict Resolution Strategy**: `replace`
- **Compression codec**: `NONE` (для простоты)

**Дополнительные настройки (Advanced)**:
- **Block Size**: `32 MB`
- **Replication Factor**: `1`

**Auto Terminate Relationships**:
- ☑ `success` - отметить
- ☑ `failure` - отметить

### Шаг 3: Соединить процессоры

1. Соедините выход `success` процессора **ConsumeKafka** с входом **PutHDFS**
2. Выберите relationship: `success`

### Шаг 4: Запустить процессоры

1. Щелкните правой кнопкой на canvas → **Refresh**
2. Выделите оба процессора (Ctrl+A)
3. Нажмите **Start** (▶️)

---

## Проверка данных

### Вариант 1: Скрипт тестирования

```bash
./scripts/test.sh
```

Скрипт покажет:
- Файлы в HDFS
- Количество записей в Hive
- Топ-10 инструментов по количеству сделок
- Последние 10 сделок

### Вариант 2: Вручную через Beeline (Hive CLI)

```bash
# Подключиться к HiveServer2
docker exec -it hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root

# Выполнить SQL запросы
USE moex_data;
SHOW TABLES;

-- Количество сделок
SELECT COUNT(*) FROM trades;

-- Топ инструментов
SELECT secid, COUNT(*) as cnt
FROM trades
GROUP BY secid
ORDER BY cnt DESC
LIMIT 10;

-- Последние сделки
SELECT * FROM trades
ORDER BY tradetime DESC
LIMIT 10;
```

### Вариант 3: Проверка HDFS напрямую

```bash
# Список файлов в HDFS
docker exec hadoop-namenode hadoop fs -ls /user/hive/warehouse/moex_data.db/trades/

# Посмотреть содержимое файла
docker exec hadoop-namenode hadoop fs -cat /user/hive/warehouse/moex_data.db/trades/<filename> | head -10
```

---

## Структура данных

### Схема таблицы `trades`

| Поле | Тип | Описание |
|------|-----|----------|
| `tradeno` | BIGINT | Номер сделки |
| `tradetime` | STRING | Время сделки (YYYY-MM-DD HH:MM:SS) |
| `secid` | STRING | Код инструмента (SBER, GAZP, ...) |
| `boardid` | STRING | Код режима торгов |
| `price` | DOUBLE | Цена |
| `quantity` | BIGINT | Количество |
| `value` | DOUBLE | Объем сделки |
| `buysell` | STRING | Направление (B/S) |
| `period` | STRING | Период торгов |
| `tradingsession` | STRING | Торговая сессия |
| `systime` | STRING | Системное время |
| `ts_offset` | BIGINT | Временной offset |

### Формат хранения

- **Тип таблицы**: `EXTERNAL TABLE`
- **Формат**: JSON (JSONSerDe)
- **Сжатие**: Нет (для простоты)
- **Локация**: `/user/hive/warehouse/moex_data.db/trades/`

**Преимущества EXTERNAL TABLE**:
- ✅ Hive автоматически читает новые файлы
- ✅ Можно удалить таблицу без удаления данных
- ✅ Простота интеграции с NiFi

---

## Управление инфраструктурой

### Просмотр логов

```bash
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f hive
docker-compose logs -f nifi
docker-compose logs -f namenode
```

### Перезапуск сервиса

```bash
docker-compose restart hive
docker-compose restart nifi
```

### Остановка всех сервисов

```bash
./scripts/stop.sh
# или
docker-compose down
```

### Полная очистка (удалить все данные)

```bash
docker-compose down -v
```

**Внимание**: Это удалит все данные из HDFS, Hive и PostgreSQL!

---

## Web UI интерфейсы

| Сервис | URL | Описание |
|--------|-----|----------|
| **Hadoop NameNode** | http://localhost:9870 | Статус HDFS, датаноды, файлы |
| **NiFi** | http://localhost:8082/nifi | Управление dataflow |
| **Kafka UI** | http://localhost:8080 | Мониторинг Kafka (из Lab 1-2) |

---

## Troubleshooting

### Проблема: Hive не может создать таблицы

**Симптомы**:
```
Error: Connection refused
```

**Решение**:
1. Проверить что HiveServer2 запущен:
   ```bash
   docker ps | grep hive-server
   docker logs hive-server
   ```

2. Подождать 1-2 минуты после старта (HiveServer2 медленно запускается)

3. Попробовать создать таблицы вручную:
   ```bash
   ./scripts/create-tables.sh
   ```

### Проблема: NiFi не может писать в HDFS

**Симптомы**:
```
Failed to write to HDFS: Permission denied
```

**Решение**:
1. Проверить права на директорию:
   ```bash
   docker exec hadoop-namenode hadoop fs -ls /user/hive/warehouse/moex_data.db/
   ```

2. Исправить права:
   ```bash
   docker exec hadoop-namenode hadoop fs -chmod -R 777 /user/hive/warehouse/moex_data.db/trades
   ```

### Проблема: Нет данных в Hive

**Симптомы**:
```sql
SELECT COUNT(*) FROM trades;
-- Результат: 0
```

**Чек-лист**:
1. ✅ Kafka работает и содержит данные:
   ```bash
   cd ../kafka
   docker-compose ps
   docker exec -it moex-kafka kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic moex.trades \
     --from-beginning \
     --max-messages 10
   ```

2. ✅ MOEX collector запущен и отправляет данные:
   ```bash
   cd ../../moex-collector
   ./gradlew bootRun
   ```

3. ✅ NiFi процессоры запущены:
   - Откройте http://localhost:8082/nifi
   - Проверьте статус процессоров (зеленая галочка)
   - Посмотрите счетчики (In/Out)

4. ✅ Файлы появились в HDFS:
   ```bash
   docker exec hadoop-namenode hadoop fs -ls /user/hive/warehouse/moex_data.db/trades/
   ```

### Проблема: HDFS NameNode не запускается

**Симптомы**:
```
NameNode is in safe mode
```

**Решение**:
```bash
# Выйти из safe mode
docker exec hadoop-namenode hadoop dfsadmin -safemode leave

# Или пересоздать HDFS с нуля
docker-compose down -v
docker-compose up -d
./scripts/start.sh
```

---

## Полезные команды

### HDFS

```bash
# Создать директорию
docker exec hadoop-namenode hadoop fs -mkdir -p /path/to/dir

# Скопировать файл в HDFS
docker exec hadoop-namenode hadoop fs -put /local/file /hdfs/path

# Скачать файл из HDFS
docker exec hadoop-namenode hadoop fs -get /hdfs/path /local/file

# Удалить файл
docker exec hadoop-namenode hadoop fs -rm /hdfs/path/file

# Посмотреть использование диска
docker exec hadoop-namenode hadoop fs -df -h

# Статус DataNodes
docker exec hadoop-namenode hdfs dfsadmin -report
```

### Hive

```bash
# Подключиться к Hive CLI
docker exec -it hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root

# Выполнить SQL из файла
docker exec -i hive-server /opt/hive/bin/beeline -u jdbc:hive2://localhost:10000 -n root -f /scripts/query.sql

# Посмотреть конфигурацию Hive
docker exec hive-server cat /opt/hive/conf/hive-site.xml

# Проверить версию
docker exec hive-server /opt/hive/bin/hive --version
```

### PostgreSQL (Metastore)

```bash
# Подключиться к БД
docker exec -it hive-metastore-db psql -U hive -d metastore

# Посмотреть таблицы Metastore
docker exec -it hive-metastore-db psql -U hive -d metastore -c "\dt"

# Проверить сохраненные метаданные
docker exec -it hive-metastore-db psql -U hive -d metastore -c "SELECT * FROM TBLS;"
```

---

## Дальнейшие шаги

После успешного завершения Lab 3:

- ✅ Данные из Kafka сохраняются в Hive через NiFi
- ✅ Можно выполнять SQL запросы к биржевым данным
- ✅ HDFS хранит данные в распределенном виде

**Следующая лаборатория (Lab 4)**: Пакетная обработка данных с Apache Hadoop MapReduce.

---

## Структура проекта

```
docker/lab3/
├── docker-compose.yml       # Вся инфраструктура
├── hadoop.env               # Конфигурация Hadoop
├── scripts/
│   ├── start.sh             # Запуск всей инфраструктуры
│   ├── stop.sh              # Остановка
│   ├── test.sh              # Проверка работы
│   └── create-tables.sh     # Создание таблиц вручную
└── README.md                # Эта документация
```

---

## Полезные ссылки

- [Apache Hive Documentation](https://hive.apache.org/)
- [Apache Hadoop HDFS](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [BDE2020 Docker Images](https://github.com/big-data-europe/docker-hadoop)

---

## Авторы

Студенты МИФИ, курс "Технологии обработки больших данных"
