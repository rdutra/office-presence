#!/usr/bin/env bash

# Sync Assets to Firebase Public Directory
# This script copies CSS and JS files from public/ to firebase_public/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$PROJECT_DIR/public"
DEST_DIR="$PROJECT_DIR/firebase_public"

echo "================================================"
echo "Syncing Assets to Firebase Public Directory"
echo "================================================"
echo ""

# Create directories if they don't exist
mkdir -p "$DEST_DIR/css"
mkdir -p "$DEST_DIR/js"

# Copy CSS files
echo "Copying CSS files..."
cp -v "$SOURCE_DIR/css/"*.css "$DEST_DIR/css/"

# Copy JS files (excluding registration.js which isn't needed for Firebase)
echo ""
echo "Copying JS files..."
for js_file in "$SOURCE_DIR/js/"*.js; do
    filename=$(basename "$js_file")
    # Skip registration.js and timezone.js as they're not needed for Firebase
    if [[ "$filename" != "registration.js" && "$filename" != "timezone.js" ]]; then
        cp -v "$js_file" "$DEST_DIR/js/"
    fi
done

echo ""
echo "================================================"
echo "✓ Assets synced successfully"
echo "================================================"
echo ""
echo "Files in firebase_public/css/:"
ls -la "$DEST_DIR/css/"
echo ""
echo "Files in firebase_public/js/:"
ls -la "$DEST_DIR/js/"
