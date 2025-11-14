#!/usr/bin/env bash

# Office Presence Server Startup Script
# Starts both the Puma web server and Firebase sync scheduler

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
PID_DIR="$PROJECT_DIR/tmp/pids"

# Create directories if they don't exist
mkdir -p "$LOG_DIR"
mkdir -p "$PID_DIR"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Office Presence Server Startup"
echo "================================================"
echo ""

cd "$PROJECT_DIR"

# Check if Puma is already running
if [ -f "$PID_DIR/puma.pid" ]; then
    PID=$(cat "$PID_DIR/puma.pid")
    if ps -p $PID > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Puma is already running (PID: $PID)${NC}"
    else
        echo "Cleaning up stale Puma PID file..."
        rm -f "$PID_DIR/puma.pid"
    fi
fi

# Check if Firebase scheduler is already running
if [ -f "$PID_DIR/firebase_scheduler.pid" ]; then
    PID=$(cat "$PID_DIR/firebase_scheduler.pid")
    if ps -p $PID > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Firebase scheduler is already running (PID: $PID)${NC}"
    else
        echo "Cleaning up stale Firebase scheduler PID file..."
        rm -f "$PID_DIR/firebase_scheduler.pid"
    fi
fi

echo ""
echo "Starting services..."
echo ""

# Start Puma server
echo -e "${GREEN}→${NC} Starting Puma web server..."
nohup bundle exec puma -C config/puma.rb > /dev/null 2>&1 &
sleep 3

if [ -f "$PID_DIR/puma.pid" ]; then
    PID=$(cat "$PID_DIR/puma.pid")
    if ps -p $PID > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Puma started successfully (PID: $PID)"
        echo -e "  ${GREEN}✓${NC} Server running at http://localhost:9292"
    else
        echo -e "  ${RED}✗${NC} Failed to start Puma"
        exit 1
    fi
else
    echo -e "  ${RED}✗${NC} Puma PID file not found"
    exit 1
fi

echo ""

# Start Firebase scheduler
echo -e "${GREEN}→${NC} Starting Firebase sync scheduler..."
bundle exec ruby bin/firebase_scheduler.rb >> "$LOG_DIR/firebase_scheduler.log" 2>&1 &
SCHEDULER_PID=$!
echo $SCHEDULER_PID > "$PID_DIR/firebase_scheduler.pid"
sleep 2

if ps -p $SCHEDULER_PID > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Firebase scheduler started successfully (PID: $SCHEDULER_PID)"
    echo -e "  ${GREEN}✓${NC} Syncing every 5 minutes"
else
    echo -e "  ${RED}✗${NC} Failed to start Firebase scheduler"
    rm -f "$PID_DIR/firebase_scheduler.pid"
    exit 1
fi

echo ""
echo "================================================"
echo -e "${GREEN}✓ All services started successfully!${NC}"
echo "================================================"
echo ""
echo "Service Status:"
echo "  • Puma Server:         http://localhost:9292"
echo "  • Dashboard:           http://localhost:9292/dashboard"
echo "  • Firebase Scheduler:  Running (every 5 min)"
echo ""
echo "Logs:"
echo "  • Puma:               $LOG_DIR/puma_stdout.log"
echo "  •                     $LOG_DIR/puma_stderr.log"
echo "  • Firebase Scheduler: $LOG_DIR/firebase_scheduler.log"
echo ""
echo "To stop services, run:"
echo "  ./bin/server_stop.sh"
echo ""
echo "To check status, run:"
echo "  ./bin/server_status.sh"
echo ""
