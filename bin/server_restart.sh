#!/usr/bin/env bash

# Office Presence Server Restart Script
# Restarts both the Puma web server and Firebase sync scheduler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================"
echo "Office Presence Server Restart"
echo "================================================"
echo ""

# Stop services
"$SCRIPT_DIR/server_stop.sh"

echo ""
echo "Waiting 3 seconds..."
sleep 3
echo ""

# Start services
"$SCRIPT_DIR/server_start.sh"
