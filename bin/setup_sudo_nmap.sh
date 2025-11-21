#!/bin/bash
# Setup passwordless sudo for nmap (required for DNS-SD scanning)

set -e

echo "=== Office Presence - Nmap Sudo Setup ==="
echo ""
echo "This script will configure passwordless sudo for nmap."
echo "This is required for DNS-SD device discovery."
echo ""

# Find nmap location
NMAP_PATH=$(which nmap 2>/dev/null || echo "")

if [ -z "$NMAP_PATH" ]; then
    echo "❌ Error: nmap not found in PATH"
    echo ""
    echo "Please install nmap first:"
    echo "  brew install nmap"
    echo ""
    exit 1
fi

echo "Found nmap at: $NMAP_PATH"
echo ""

# Get current user
CURRENT_USER=$(whoami)

# Create sudoers entry
SUDOERS_LINE="$CURRENT_USER ALL=(ALL) NOPASSWD: $NMAP_PATH"

echo "This will add the following line to /etc/sudoers.d/nmap:"
echo "  $SUDOERS_LINE"
echo ""
echo "⚠️  You will be asked for your password ONCE to configure this."
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Create sudoers file
echo "$SUDOERS_LINE" | sudo tee /etc/sudoers.d/nmap > /dev/null

# Set proper permissions (required for sudoers files)
sudo chmod 0440 /etc/sudoers.d/nmap

# Validate sudoers syntax
if sudo visudo -c -f /etc/sudoers.d/nmap &>/dev/null; then
    echo ""
    echo "✅ Success! Nmap sudo configuration complete."
    echo ""
    echo "Testing passwordless sudo..."
    if sudo -n nmap --version &>/dev/null; then
        echo "✅ Test passed! You can now run 'sudo nmap' without a password."
    else
        echo "⚠️  Test failed. You may need to log out and back in."
    fi
else
    echo ""
    echo "❌ Error: Invalid sudoers syntax. Rolling back..."
    sudo rm /etc/sudoers.d/nmap
    exit 1
fi

echo ""
echo "Next steps:"
echo "  1. Run the migration: bundle exec ruby bin/migrate_dns_sd.rb"
echo "  2. Restart the server: ./bin/server_restart.sh"
echo ""
