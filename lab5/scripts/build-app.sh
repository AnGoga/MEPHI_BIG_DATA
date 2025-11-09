#!/bin/bash
set -e

echo "🔨 Building Spark Streaming Application"

cd "spark-streaming"

JAR_PATH="build/libs/moex-streaming-1.0.0-all.jar"

if [ -f "$JAR_PATH" ]; then
    echo "✅ JAR built successfully: $JAR_PATH"
    ls -lh "$JAR_PATH"
else
    echo "❌ JAR build failed"
    exit 1
fi
