#!/usr/bin/env bash

# Firebase Setup Helper Script
# This script helps you configure Firebase for your office presence dashboard
# Usage: ./setup_firebase.sh (do NOT use 'source')

set -e

# Check if being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "❌ Error: This script should be executed, not sourced."
    echo ""
    echo "Please run it like this:"
    echo "  ./setup_firebase.sh"
    echo ""
    echo "NOT like this:"
    echo "  source setup_firebase.sh"
    return 1 2>/dev/null || exit 1
fi

echo "================================================"
echo "Firebase Dashboard Setup Helper"
echo "================================================"
echo ""

# Check if Firebase CLI is installed
if command -v firebase &> /dev/null; then
    FIREBASE_CMD=("firebase")
    echo "✓ Firebase CLI found"
elif command -v npx &> /dev/null; then
    FIREBASE_CMD=("npx" "-p" "firebase-tools" "firebase")
    echo "✓ Using 'npx firebase' as fallback"
else
    echo "❌ Firebase CLI not found and npx not available!"
    echo ""
    echo "Please install it first:"
    echo "  npm install -g firebase-tools"
    echo ""
    exit 1
fi

echo ""

# Check if user is logged in
echo "Checking Firebase login status..."
if ! "${FIREBASE_CMD[@]}" projects:list &> /dev/null; then
    echo ""
    echo "Please login to Firebase:"
    "${FIREBASE_CMD[@]}" login
fi

echo ""
echo "✓ Logged in to Firebase"
echo ""

# Show available projects
echo "Your Firebase projects:"
echo "----------------------"
"${FIREBASE_CMD[@]}" projects:list
echo ""

# Get project ID
read -p "Enter your Firebase Project ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID cannot be empty"
    exit 1
fi

# Update .firebaserc
echo ""
echo "Updating .firebaserc..."
cat > .firebaserc << EOF
{
  "projects": {
    "default": "$PROJECT_ID"
  }
}
EOF
echo "✓ Updated .firebaserc"

# Guide user to get Firebase config
echo ""
echo "================================================"
echo "Next Steps:"
echo "================================================"
echo ""
echo "1. Go to Firebase Console:"
echo "   https://console.firebase.google.com/project/$PROJECT_ID/settings/general"
echo ""
echo "2. Scroll to 'Your apps' section"
echo ""
echo "3. If no web app exists:"
echo "   - Click the web icon (</>) to add a web app"
echo "   - Name it 'Office Presence Dashboard'"
echo ""
echo "4. Copy the Firebase configuration values"
echo ""
echo "5. Update these files with your config:"
echo "   - .env.firebase (all the FIREBASE_* variables)"
echo "   - firebase_public/index.html (the firebaseConfig object around line 343)"
echo ""
echo "6. Enable Realtime Database:"
echo "   https://console.firebase.google.com/project/$PROJECT_ID/database"
echo "   - Click 'Create Database'"
echo "   - Choose location (e.g., us-central1)"
echo "   - Start in test mode (we'll deploy proper rules later)"
echo ""
echo "================================================"
echo ""

read -p "Press Enter when you've completed the above steps..."

echo ""
echo "Deploying to Firebase..."
echo ""

# Deploy database rules first
echo "Deploying database rules..."
"${FIREBASE_CMD[@]}" deploy --only database

echo ""
echo "Deploying hosting..."
"${FIREBASE_CMD[@]}" deploy --only hosting

echo ""
echo "================================================"
echo "✓ Deployment Complete!"
echo "================================================"
echo ""
echo "Your dashboard is live at:"
echo "  https://$PROJECT_ID.web.app"
echo ""
echo "Next, test the sync script:"
echo "  bundle exec ruby bin/sync_to_firebase.rb"
echo ""
echo "Then set up automatic sync (every 5 minutes):"
echo "  crontab -e"
echo ""
echo "Add this line:"
echo "  */5 * * * * cd $(pwd) && /usr/bin/bundle exec ruby bin/sync_to_firebase.rb >> logs/firebase_sync.log 2>&1"
echo ""
echo "Create logs directory:"
echo "  mkdir -p logs"
echo ""
echo "See FIREBASE_SETUP.md for complete documentation."
echo "================================================"
