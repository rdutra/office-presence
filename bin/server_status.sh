#!/usr/bin/env bash

# Office Presence Server Status Script
# Checks the status of Puma web server and Firebase sync scheduler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_DIR="$PROJECT_DIR/tmp/pids"
LOG_DIR="$PROJECT_DIR/logs"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "Office Presence Server Status"
echo "================================================"
echo ""

# Check Puma
echo "Puma Web Server:"
if [ -f "$PID_DIR/puma.pid" ]; then
    PID=$(cat "$PID_DIR/puma.pid")
    if ps -p $PID > /dev/null 2>&1; then
        UPTIME=$(ps -o etime= -p $PID | tr -d ' ')
        echo -e "  Status:  ${GREEN}● Running${NC}"
        echo -e "  PID:     $PID"
        echo -e "  Uptime:  $UPTIME"
        echo -e "  URL:     http://localhost:9292"
    else
        echo -e "  Status:  ${RED}● Stopped${NC} (stale PID file)"
        echo -e "  PID:     $PID (not running)"
    fi
else
    echo -e "  Status:  ${RED}● Stopped${NC}"
    echo -e "  PID:     none"
fi

echo ""

# Check Firebase scheduler
echo "Firebase Sync Scheduler:"
if [ -f "$PID_DIR/firebase_scheduler.pid" ]; then
    PID=$(cat "$PID_DIR/firebase_scheduler.pid")
    if ps -p $PID > /dev/null 2>&1; then
        UPTIME=$(ps -o etime= -p $PID | tr -d ' ')
        echo -e "  Status:  ${GREEN}● Running${NC}"
        echo -e "  PID:     $PID"
        echo -e "  Uptime:  $UPTIME"
        echo -e "  Interval: Every 5 minutes"
        
        # Show last sync from log if available
        if [ -f "$LOG_DIR/firebase_scheduler.log" ]; then
            LAST_SYNC=$(grep "Sync completed successfully" "$LOG_DIR/firebase_scheduler.log" | tail -1 | awk '{print $1, $2}')
            if [ ! -z "$LAST_SYNC" ]; then
                echo -e "  Last sync: $LAST_SYNC"
            fi
        fi
    else
        echo -e "  Status:  ${RED}● Stopped${NC} (stale PID file)"
        echo -e "  PID:     $PID (not running)"
    fi
else
    echo -e "  Status:  ${RED}● Stopped${NC}"
    echo -e "  PID:     none"
fi

echo ""
echo "================================================"
echo ""
echo "Commands:"
echo "  Start:   ./bin/server_start.sh"
echo "  Stop:    ./bin/server_stop.sh"
echo "  Restart: ./bin/server_restart.sh"
echo ""
echo "Logs:"
echo "  Puma:      tail -f $LOG_DIR/puma_stdout.log"
echo "  Scheduler: tail -f $LOG_DIR/firebase_scheduler.log"
echo ""
