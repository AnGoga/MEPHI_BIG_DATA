#!/bin/bash
set -e

echo "=========================================="
echo "🔨 Building MapReduce Job"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/../mapreduce-job"

echo -e "${YELLOW}Building JAR with Gradle...${NC}"
./gradlew clean shadowJar

JAR_PATH="build/libs/moex-mapreduce-1.0.0-all.jar"

if [ -f "$JAR_PATH" ]; then
    echo ""
    echo -e "${GREEN}✅ JAR built successfully!${NC}"
    ls -lh "$JAR_PATH"
else
    echo ""
    echo -e "${RED}❌ JAR build failed${NC}"
    exit 1
fi

echo ""
