#!/bin/bash

# Скрипт для просмотра сообщений в Kafka топике moex.trades

echo "📊 Viewing trades from Kafka topic..."
echo "Press Ctrl+C to stop"
echo ""

docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.trades \
  --from-beginning \
  --property print.key=true \
  --property key.separator=" | "
