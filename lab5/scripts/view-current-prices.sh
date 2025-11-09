#!/bin/bash

echo "📊 Viewing Current Prices from Kafka"
echo "Topic: moex.current_prices"
echo "Press Ctrl+C to stop"
echo ""

docker exec -it moex-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic moex.current_prices \
  --from-beginning \
  --property print.key=true \
  --property key.separator=" | " \
  --property print.timestamp=true
