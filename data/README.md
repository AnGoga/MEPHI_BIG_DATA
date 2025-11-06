# Data Directory

Эта директория содержит **все данные Docker контейнеров** для Лабораторной работы №3 (HDFS, Hive, NiFi).

## Структура

```
data/
├── postgres/              # PostgreSQL данные (Hive Metastore DB)
├── hadoop/
│   ├── namenode/          # HDFS NameNode metadata
│   ├── datanode1/         # HDFS DataNode 1 data blocks
│   └── datanode2/         # HDFS DataNode 2 data blocks
├── hive/
│   └── warehouse/         # Hive warehouse (таблицы в HDFS)
└── nifi/
    ├── conf/              # NiFi configuration
    ├── database/          # NiFi internal database
    ├── flowfile/          # NiFi FlowFile repository
    ├── content/           # NiFi Content repository
    ├── provenance/        # NiFi Provenance repository
    ├── state/             # NiFi State
    └── logs/              # NiFi logs
```

## Использование

### Автоматическое создание при запуске

Структура директорий создается автоматически при первом запуске:
```bash
./start-hadoop.sh
```

Docker контейнеры автоматически создают необходимые файлы в этих директориях.

### Очистка данных

Для полной очистки всех данных (сброс к начальному состоянию):

```bash
# Остановить контейнеры
./stop-hadoop.sh

# Удалить все данные
rm -rf data/postgres/* data/hadoop/* data/hive/* data/nifi/*

# Или удалить только конкретный компонент
rm -rf data/hadoop/namenode/*  # Только HDFS NameNode
rm -rf data/hive/*              # Только Hive warehouse
```

**ВНИМАНИЕ**: После очистки данных потребуется повторная инициализация:
```bash
./start-hadoop.sh
./init-hdfs.sh
./init-hive.sh
```

### Бэкап данных

Так как данные хранятся локально, их легко бэкапить:

```bash
# Создать backup
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# Восстановить из backup
tar -xzf backup-20251106.tar.gz
```

## Git

Директория `data/` добавлена в `.gitignore` - **данные не коммитятся в репозиторий**.

Сохраняется только структура директорий (через `.gitkeep` файлы).

## Размер данных

Ожидаемый размер после работы системы:

- **PostgreSQL**: ~10-50 MB (метаданные Hive)
- **HDFS NameNode**: ~100 MB (метаданные файловой системы)
- **HDFS DataNodes**: **зависит от объема данных** (может быть гигабайты)
- **Hive Warehouse**: ссылается на HDFS
- **NiFi**: ~500 MB - 2 GB (конфигурация, FlowFiles, провенанс)

**Совет**: Регулярно проверяйте размер:
```bash
du -sh data/*
```

## Мониторинг

Просмотр содержимого:

```bash
# HDFS через NameNode
docker exec hdfs-namenode hdfs dfs -ls -R /

# PostgreSQL
docker exec hive-metastore-db psql -U hive -d metastore -c "\dt"

# NiFi logs
tail -f data/nifi/logs/nifi-app.log
```

## Troubleshooting

### Проблема: Permission denied

```bash
# Дать права на запись (только для development!)
chmod -R 777 data/
```

### Проблема: Нет места на диске

```bash
# Проверить размер
du -sh data/*

# Очистить старые данные NiFi (provenance растет быстро)
rm -rf data/nifi/provenance/*
```

### Проблема: Corrupted data

```bash
# Полная переустановка
./stop-hadoop.sh
rm -rf data/*
./start-hadoop.sh
./init-hdfs.sh
./init-hive.sh
```

## FAQ

**Q: Можно ли перенести данные на другой компьютер?**
A: Да, просто скопируйте всю папку `data/` и запустите Docker Compose.

**Q: Зачем хранить данные локально, а не в Docker volumes?**
A:
- Легкий бэкап (просто копирование папки)
- Можно просматривать файлы напрямую
- Легко очистить всё
- Переносимость между машинами

**Q: Сколько места займут данные?**
A: Зависит от объема торговых данных. Для одного дня торгов MOEX (~2-3 млн сделок) примерно 1-2 GB в HDFS (с учетом репликации 2x и сжатия Parquet).
