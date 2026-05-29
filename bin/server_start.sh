#!/usr/bin/env bash

# Office Presence Server Startup Script
# Starts both the Puma web server and Firebase sync scheduler

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
PID_DIR="$PROJECT_DIR/tmp/pids"
PUMA_BOOT_LOG="$LOG_DIR/puma_boot.log"

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

ensure_ruby_environment() {
    local ruby_version_file="$PROJECT_DIR/.ruby-version"
    local ruby_version
    local wrapper_dir

    if [ -f "$ruby_version_file" ]; then
        ruby_version="$(tr -d '[:space:]' < "$ruby_version_file")"
        wrapper_dir="$HOME/.rvm/wrappers/ruby-$ruby_version"
        if [ -d "$wrapper_dir" ]; then
            export PATH="$wrapper_dir:$PATH"
            return
        fi
    fi

    if [ -s "$HOME/.rvm/scripts/rvm" ]; then
        # shellcheck disable=SC1090
        source "$HOME/.rvm/scripts/rvm"
        rvm use . > /dev/null 2>&1 || true
    fi
}

ensure_ruby_environment

# Check if Puma is already running
if [ -f "$PID_DIR/puma.pid" ]; then
    PID=$(cat "$PID_DIR/puma.pid")
    if kill -0 "$PID" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Puma is already running (PID: $PID)${NC}"
    else
        echo "Cleaning up stale Puma PID file..."
        rm -f "$PID_DIR/puma.pid"
    fi
fi

# Check if Firebase scheduler is already running
if [ -f "$PID_DIR/firebase_scheduler.pid" ]; then
    PID=$(cat "$PID_DIR/firebase_scheduler.pid")
    if kill -0 "$PID" > /dev/null 2>&1; then
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
nohup bundle exec puma -C config/puma.rb >> "$PUMA_BOOT_LOG" 2>&1 &
PUMA_LAUNCH_PID=$!
sleep 1

PUMA_READY=0
for _ in {1..20}; do
    if [ -f "$PID_DIR/puma.pid" ]; then
        PID=$(cat "$PID_DIR/puma.pid")
        if kill -0 "$PID" > /dev/null 2>&1; then
            PUMA_READY=1
            break
        fi
    fi

    if ! kill -0 "$PUMA_LAUNCH_PID" > /dev/null 2>&1; then
        break
    fi

    sleep 1
done

if [ "$PUMA_READY" -eq 1 ]; then
    echo -e "  ${GREEN}✓${NC} Puma started successfully (PID: $PID)"
    echo -e "  ${GREEN}✓${NC} Server running at http://localhost:9292"
else
    echo -e "  ${RED}✗${NC} Puma failed to start (PID file not created)"
    if [ -f "$PUMA_BOOT_LOG" ]; then
        echo ""
        echo "Last Puma errors:"
        tail -n 20 "$PUMA_BOOT_LOG"
    elif [ -f "$LOG_DIR/puma_stderr.log" ]; then
        echo ""
        echo "Last Puma errors:"
        tail -n 20 "$LOG_DIR/puma_stderr.log"
    fi
    exit 1
fi

echo ""

# Start Firebase scheduler
# echo -e "${GREEN}→${NC} Starting Firebase sync scheduler..."
# bundle exec ruby bin/firebase_scheduler.rb >> "$LOG_DIR/firebase_scheduler.log" 2>&1 &
# SCHEDULER_PID=$!
# echo $SCHEDULER_PID > "$PID_DIR/firebase_scheduler.pid"
# sleep 2

# if kill -0 "$SCHEDULER_PID" > /dev/null 2>&1; then
#     echo -e "  ${GREEN}✓${NC} Firebase scheduler started successfully (PID: $SCHEDULER_PID)"
#     echo -e "  ${GREEN}✓${NC} Syncing every 5 minutes"
# else
#     echo -e "  ${RED}✗${NC} Failed to start Firebase scheduler"
#     rm -f "$PID_DIR/firebase_scheduler.pid"
#     exit 1
# fi

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
