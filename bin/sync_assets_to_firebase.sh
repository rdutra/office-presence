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
mkdir -p "$DEST_DIR/img"
mkdir -p "$DEST_DIR/video"

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

# Copy images
echo ""
echo "Copying images..."
cp -R "$SOURCE_DIR/img/"* "$DEST_DIR/img/"

# Copy videos
echo ""
echo "Copying videos..."
if [ -d "$SOURCE_DIR/video" ]; then
    cp -R "$SOURCE_DIR/video/"* "$DEST_DIR/video/"
fi

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
echo ""
echo "Files in firebase_public/video/:"
if [ -d "$DEST_DIR/video/" ]; then
    ls -la "$DEST_DIR/video/"
else
    echo "Directory does not exist"
fi
