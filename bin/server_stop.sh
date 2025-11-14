#!/usr/bin/env bash

# Office Presence Server Stop Script
# Stops both the Puma web server and Firebase sync scheduler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_DIR="$PROJECT_DIR/tmp/pids"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Office Presence Server Shutdown"
echo "================================================"
echo ""

cd "$PROJECT_DIR"

# Stop Puma
if [ -f "$PID_DIR/puma.pid" ]; then
    PID=$(cat "$PID_DIR/puma.pid")
    if ps -p $PID > /dev/null 2>&1; then
        echo -e "${GREEN}→${NC} Stopping Puma server (PID: $PID)..."
        kill $PID
        sleep 2
        
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "  ${YELLOW}⚠${NC} Puma didn't stop gracefully, forcing..."
            kill -9 $PID
        fi
        
        rm -f "$PID_DIR/puma.pid"
        echo -e "  ${GREEN}✓${NC} Puma stopped"
    else
        echo -e "${YELLOW}⚠${NC} Puma is not running"
        rm -f "$PID_DIR/puma.pid"
    fi
else
    echo -e "${YELLOW}⚠${NC} Puma PID file not found"
fi

echo ""

# Stop Firebase scheduler
if [ -f "$PID_DIR/firebase_scheduler.pid" ]; then
    PID=$(cat "$PID_DIR/firebase_scheduler.pid")
    if ps -p $PID > /dev/null 2>&1; then
        echo -e "${GREEN}→${NC} Stopping Firebase scheduler (PID: $PID)..."
        kill $PID
        sleep 2
        
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "  ${YELLOW}⚠${NC} Scheduler didn't stop gracefully, forcing..."
            kill -9 $PID
        fi
        
        rm -f "$PID_DIR/firebase_scheduler.pid"
        echo -e "  ${GREEN}✓${NC} Firebase scheduler stopped"
    else
        echo -e "${YELLOW}⚠${NC} Firebase scheduler is not running"
        rm -f "$PID_DIR/firebase_scheduler.pid"
    fi
else
    echo -e "${YELLOW}⚠${NC} Firebase scheduler PID file not found"
fi

echo ""
echo "================================================"
echo -e "${GREEN}✓ All services stopped${NC}"
echo "================================================"
echo ""
