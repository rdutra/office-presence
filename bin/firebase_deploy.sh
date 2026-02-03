#!/usr/bin/env bash

# Firebase Deploy Script
# This script generates index.html from the dashboard_modern.erb template,
# injects credentials from .env.firebase, and deploys to Firebase

set -e

# Parse template parameter
TEMPLATE="modern"
FIREBASE_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --template)
            TEMPLATE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Firebase Deploy Script"
            echo ""
            echo "Usage:"
            echo "  ./bin/firebase_deploy.sh [--template TEMPLATE] [firebase-options]"
            echo ""
            echo "Options:"
            echo "  --template TEMPLATE    Template to deploy (modern, geocities, christmas, summer)"
            echo "                         Default: modern"
            echo ""
            echo "Examples:"
            echo "  ./bin/firebase_deploy.sh                          # Deploy modern template"
            echo "  ./bin/firebase_deploy.sh --template christmas     # Deploy christmas template"
            echo "  ./bin/firebase_deploy.sh --template geocities --only hosting"
            echo ""
            echo "The script will:"
            echo "  1. Generate index.html from the selected template"
            echo "  2. Load Firebase credentials from .env.firebase"
            echo "  3. Inject them into the generated HTML"
            echo "  4. Deploy to Firebase with your options"
            echo "  5. Restore placeholder values in index.html"
            echo ""
            exit 0
            ;;
        *)
            FIREBASE_ARGS+=("$1")
            shift
            ;;
    esac
done

# Validate template
case $TEMPLATE in
    modern|geocities|christmas|summer)
        ;;
    *)
        echo "❌ Error: Invalid template '$TEMPLATE'"
        echo "Valid templates: modern, geocities, christmas, summer"
        exit 1
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$PROJECT_DIR/firebase_public"

# Determine Firebase command
if command -v firebase &> /dev/null; then
    FIREBASE_CMD="firebase"
elif command -v npx &> /dev/null; then
    echo "⚠️ 'firebase' command not found, using 'npx firebase'..."
    FIREBASE_CMD="npx -p firebase-tools firebase"
else
    echo "❌ Error: Neither 'firebase' nor 'npx' found. Please install firebase-tools."
    exit 1
fi


cd "$PROJECT_DIR"

echo "================================================"
echo "Firebase Deploy with Config Injection"
echo "================================================"
echo "Template: $TEMPLATE"
echo ""

# Sync assets (CSS/JS) to firebase_public
echo "✓ Syncing assets to firebase_public..."
"$SCRIPT_DIR/sync_assets_to_firebase.sh"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to sync assets"
    exit 1
fi

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

# Generate HTML from ERB template
echo "✓ Generating HTML from dashboard_${TEMPLATE}.erb template..."
bundle exec ruby "$SCRIPT_DIR/generate_firebase_html.rb" "$TEMPLATE"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to generate HTML from template"
    exit 1
fi

# Backup current index.html
if [ -f "$PUBLIC_DIR/index.html" ]; then
    cp "$PUBLIC_DIR/index.html" "$PUBLIC_DIR/index.html.bak"
    echo "✓ Backed up generated index.html"
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
$FIREBASE_CMD deploy "${FIREBASE_ARGS[@]}"

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
