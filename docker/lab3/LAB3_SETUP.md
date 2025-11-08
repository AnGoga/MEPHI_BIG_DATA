# Простой запуск Lab3 инфраструктуры

## ✅ Гарантированно работающее решение

Эта инструкция использует проверенный образ Apache Hive 3.1.3 с правильной архитектурой.

---

## 📋 Шаг 1: Остановить старую инфраструктуру

```bash
cd /mnt/c/Users/Angoga/IdeaProjects/MEPHI_BIG_DATA/docker/lab3

# Остановить и удалить ВСЕ контейнеры и данные
docker-compose down -v

# Удалить все контейнеры lab3 (если остались)
docker rm -f $(docker ps -a | grep lab3 | awk '{print $1}') 2>/dev/null || true
```

---

## 📋 Шаг 2: Получить новые файлы

```bash
cd /mnt/c/Users/Angoga/IdeaProjects/MEPHI_BIG_DATA

# Получить последние изменения
git fetch origin
git pull origin claude/explore-lab3-infrastructure-011CUuzXLA4AXV7jSmn4mZcc
```

---

## 📋 Шаг 3: Запустить инфраструктуру

```bash
cd docker/lab3

# Запустить ВСЕ сервисы
docker-compose up -d

# Подождать 3-5 минут для полной инициализации
```

---

## 📋 Шаг 4: Проверить статус (через 5 минут)

```bash
# Посмотреть статус контейнеров
docker-compose ps

# Проверить что Metastore запустился
docker logs lab3-hive-metastore --tail 50

# Проверить что HiveServer2 запустился
docker logs lab3-hiveserver2 --tail 50

# Проверить порт 9083 (Metastore)
docker exec lab3-hive-metastore netstat -tuln | grep 9083

# Проверить порт 10000 (HiveServer2)
docker exec lab3-hiveserver2 netstat -tuln | grep 10000
```

---

## ✅ Ожидаемый результат

После успешного запуска вы должны увидеть:

```bash
$ docker-compose ps
NAME                  IMAGE                              STATUS
lab3-postgres         postgres:11                        Up (healthy)
lab3-namenode         bde2020/hadoop-namenode:2.0.0...   Up (healthy)
lab3-datanode         bde2020/hadoop-datanode:2.0.0...   Up
lab3-hive-metastore   apache/hive:3.1.3                  Up (healthy)
lab3-hiveserver2      apache/hive:3.1.3                  Up (healthy)
lab3-nifi             apache/nifi:1.23.2                 Up (healthy)
```

И порты должны слушаться:

```bash
$ docker exec lab3-hive-metastore netstat -tuln | grep 9083
tcp        0      0 0.0.0.0:9083            0.0.0.0:*               LISTEN

$ docker exec lab3-hiveserver2 netstat -tuln | grep 10000
tcp        0      0 0.0.0.0:10000           0.0.0.0:*               LISTEN
```

---

## 🌐 Доступ к сервисам

- **HDFS NameNode UI:** http://localhost:9870
- **HiveServer2 UI:** http://localhost:10002
- **NiFi UI:** http://localhost:8080 (логин: admin / adminadminadmin)
- **PostgreSQL:** localhost:5432 (user: hive, password: hive, db: metastore)

---

## 🔌 Подключение к Hive

### Через beeline (из контейнера):

```bash
docker exec -it lab3-hiveserver2 beeline -u jdbc:hive2://localhost:10000
```

### Через JDBC (из приложения):

```
jdbc:hive2://localhost:10000
```

---

## 🐛 Troubleshooting

### Если Metastore не запускается:

```bash
# Посмотреть логи PostgreSQL
docker logs lab3-postgres

# Проверить что схема создалась
docker exec lab3-postgres psql -U hive -d metastore -c "\dt"

# Принудительно пересоздать схему
docker exec lab3-hive-metastore /opt/hive/bin/schematool -dbType postgres -initSchema
```

### Если HiveServer2 не запускается:

```bash
# Проверить что Metastore доступен
docker exec lab3-hiveserver2 nc -zv lab3-hive-metastore 9083

# Если не доступен - перезапустить HiveServer2
docker restart lab3-hiveserver2
```

### Полный перезапуск:

```bash
cd docker/lab3

# Остановить все
docker-compose down

# Подождать 10 секунд
sleep 10

# Запустить заново
docker-compose up -d

# Подождать 5 минут
sleep 300
```

---

## 📝 Что изменилось по сравнению со старой инфраструктурой

| Параметр | Старое | Новое |
|----------|--------|-------|
| Образ Hive | bde2020/hive:2.3.2 | apache/hive:3.1.3 |
| Metastore | В одном контейнере с HiveServer2 ❌ | Отдельный контейнер ✅ |
| Healthchecks | Нет ❌ | Есть ✅ |
| Порядок запуска | Случайный ❌ | Правильный с depends_on ✅ |
| Инициализация схемы | Ручная ❌ | Автоматическая ✅ |

---

## 🎯 Следующие шаги после успешного запуска

1. Создать таблицу в Hive для данных MOEX
2. Настроить NiFi для перекачки данных из Kafka в Hive
3. Проверить что данные сохраняются

---

**Время установки:** 5-7 минут
**Требования:** Docker, Docker Compose, 4GB RAM
**Сложность:** Низкая ✅
