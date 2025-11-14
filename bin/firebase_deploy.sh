#!/usr/bin/env bash

# Firebase Deploy Script
# This script injects credentials from .env.firebase and deploys to Firebase

set -e

# Show help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Firebase Deploy Script"
    echo ""
    echo "Usage:"
    echo "  ./bin/firebase_deploy.sh [firebase-options]"
    echo ""
    echo "Examples:"
    echo "  ./bin/firebase_deploy.sh                    # Deploy everything"
    echo "  ./bin/firebase_deploy.sh --only hosting     # Deploy dashboard HTML only"
    echo "  ./bin/firebase_deploy.sh --only database    # Deploy security rules only"
    echo ""
    echo "The script will:"
    echo "  1. Load Firebase credentials from .env.firebase"
    echo "  2. Inject them into firebase_public/index.html"
    echo "  3. Deploy to Firebase with your options"
    echo "  4. Restore placeholder values in index.html"
    echo ""
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$PROJECT_DIR/firebase_public"

cd "$PROJECT_DIR"

echo "================================================"
echo "Firebase Deploy with Config Injection"
echo "================================================"
echo ""

# Check if .env.firebase exists
if [ ! -f ".env.firebase" ]; then
    echo "❌ Error: .env.firebase not found!"
    echo ""
    echo "Please create .env.firebase with your Firebase configuration."
    exit 1
fi

# Load environment variables
export $(grep -v '^#' .env.firebase | xargs)

# Check if required variables are set
if [ -z "$FIREBASE_API_KEY" ] || [ -z "$FIREBASE_PROJECT_ID" ]; then
    echo "❌ Error: Required Firebase variables not set in .env.firebase"
    echo ""
    echo "Please ensure these variables are set:"
    echo "  FIREBASE_API_KEY"
    echo "  FIREBASE_AUTH_DOMAIN"
    echo "  FIREBASE_DATABASE_URL"
    echo "  FIREBASE_PROJECT_ID"
    echo "  FIREBASE_STORAGE_BUCKET"
    echo "  FIREBASE_MESSAGING_SENDER_ID"
    echo "  FIREBASE_APP_ID"
    exit 1
fi

# Backup current index.html
if [ -f "$PUBLIC_DIR/index.html" ]; then
    cp "$PUBLIC_DIR/index.html" "$PUBLIC_DIR/index.html.bak"
    echo "✓ Backed up index.html"
fi

# Inject environment variables into index.html
echo "✓ Injecting Firebase config from .env.firebase..."
sed -e "s|YOUR_API_KEY_HERE|$FIREBASE_API_KEY|g" \
    -e "s|YOUR_PROJECT_ID\.firebaseapp\.com|$FIREBASE_AUTH_DOMAIN|g" \
    -e "s|https://YOUR_PROJECT_ID-default-rtdb\.firebaseio\.com|$FIREBASE_DATABASE_URL|g" \
    -e "s|YOUR_PROJECT_ID|$FIREBASE_PROJECT_ID|g" \
    -e "s|YOUR_MESSAGING_SENDER_ID|$FIREBASE_MESSAGING_SENDER_ID|g" \
    -e "s|YOUR_APP_ID|$FIREBASE_APP_ID|g" \
    "$PUBLIC_DIR/index.html.bak" > "$PUBLIC_DIR/index.html.tmp"

mv "$PUBLIC_DIR/index.html.tmp" "$PUBLIC_DIR/index.html"

echo ""
echo "Deploying to Firebase..."
echo ""

# Deploy with any additional arguments passed to the script
# Examples:
#   ./firebase_deploy.sh                    # Deploy everything
#   ./firebase_deploy.sh --only hosting     # Deploy only hosting
#   ./firebase_deploy.sh --only database    # Deploy only database rules
firebase deploy "$@"

DEPLOY_STATUS=$?

# Restore original index.html (with placeholders)
if [ -f "$PUBLIC_DIR/index.html.bak" ]; then
    mv "$PUBLIC_DIR/index.html.bak" "$PUBLIC_DIR/index.html"
    echo ""
    echo "✓ Restored index.html with placeholders"
fi

if [ $DEPLOY_STATUS -eq 0 ]; then
    echo ""
    echo "================================================"
    echo "✓ Deploy successful!"
    echo "================================================"
    echo ""
else
    echo ""
    echo "================================================"
    echo "✗ Deploy failed"
    echo "================================================"
    echo ""
    exit $DEPLOY_STATUS
fi
