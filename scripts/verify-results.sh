#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

LOG_FILE="logs/SerializerBenchmark_Log.csv"
ERROR_FILE="logs/SerializerBenchmark_Errors.tsv"

echo "[INFO] Verifying benchmark results..."
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[INFO] Verifying benchmark results...${NC}"

if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}[ERROR] Log file not found: $LOG_FILE${NC}"
    exit 1
fi

# Check if log file is non-empty (expecting at least header + 1 line)
LINE_COUNT=$(wc -l < "$LOG_FILE")
if [ "$LINE_COUNT" -lt 2 ]; then
    echo -e "${RED}[ERROR] Log file is empty or contains only headers.${NC}"
    exit 1
fi

echo -e "${GREEN}[SUCCESS] Log file verified ($LINE_COUNT lines).${NC}"

if [ -f "$ERROR_FILE" ]; then
    ERROR_COUNT=$(wc -l < "$ERROR_FILE")
    if [ "$ERROR_COUNT" -gt 1 ]; then
        echo -e "${YELLOW}[WARNING] Errors detected during run ($((ERROR_COUNT-1)) errors).${NC}"
        echo -e "${YELLOW}[INFO] Check $ERROR_FILE for details.${NC}"
    else
        echo -e "${GREEN}[INFO] No errors reported in $ERROR_FILE.${NC}"
    fi
fi
