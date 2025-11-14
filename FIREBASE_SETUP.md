# Firebase Dashboard Setup

This guide explains how to deploy your office presence dashboard to Firebase Hosting (free tier) and sync data from your local server.

## Architecture Overview

- **Local Server**: Continues to run network scanning and collect presence data
- **Firebase Realtime Database**: Stores dashboard data in the cloud
- **Firebase Hosting**: Serves the static HTML dashboard
- **Sync Script**: Periodically uploads data from SQLite to Firebase

## Prerequisites

1. Node.js and npm installed
2. Firebase account (free tier is sufficient)
3. Firebase CLI installed: `npm install -g firebase-tools`
4. Your Ruby server running locally with network scanning

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or select existing project
3. Follow the setup wizard
4. Enable **Realtime Database**:
   - In Firebase Console, go to "Realtime Database"
   - Click "Create Database"
   - Choose a location (e.g., `us-central1`)
   - Start in **test mode** (we'll configure rules later)

## Step 2: Configure Firebase Project

### Get Firebase Configuration

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Scroll to "Your apps" section
3. Click the web icon (`</>`) to add a web app
4. Register your app (name it "Office Presence Dashboard")
5. Copy the Firebase configuration object

### Update Configuration Files

1. **Update `.firebaserc`**:
   ```json
   {
     "projects": {
       "default": "your-actual-project-id"
     }
   }
   ```

2. **Update `.env.firebase`** with your Firebase config:
   ```bash
   FIREBASE_API_KEY=AIza...
   FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
   FIREBASE_DATABASE_URL=https://your-project-default-rtdb.firebaseio.com
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_STORAGE_BUCKET=your-project.appspot.com
   FIREBASE_MESSAGING_SENDER_ID=123456789
   FIREBASE_APP_ID=1:123456789:web:abc123
   ```

3. **Update `firebase_public/index.html`**:
   - Open the file and replace the `firebaseConfig` object (around line 343) with your actual Firebase configuration

## Step 3: Configure Database Security Rules

The `database.rules.json` file allows public reads but no writes (only your sync script can write).

To deploy the rules:
```bash
firebase login
firebase deploy --only database
```

## Step 4: Deploy to Firebase Hosting

```bash
# Login to Firebase (if not already)
firebase login

# Deploy hosting
firebase deploy --only hosting
```

Your dashboard will be live at: `https://your-project-id.web.app`

## Step 5: Set Up Data Sync

The sync script (`bin/sync_to_firebase.rb`) reads from your SQLite database and uploads to Firebase.

### Install Required Gem

Add to your `Gemfile` if not already present:
```ruby
gem "dotenv"
```

Then run:
```bash
bundle install
```

### Test the Sync Script

```bash
bundle exec ruby bin/sync_to_firebase.rb
```

You should see output like:
```
============================================================
Firebase Sync - 2025-11-13 10:30:00 UTC
============================================================
Present: 5 / 12
Mapped Present: 5
Mapped Absent: 7
Top Attendees: 10
------------------------------------------------------------
✓ Successfully synced data to Firebase
  Response: 200 OK
============================================================
```

### Set Up Automatic Sync with Cron

To keep your Firebase dashboard updated, run the sync script every 5 minutes:

```bash
# Edit your crontab
crontab -e

# Add this line (adjust path to your project):
*/5 * * * * cd /Users/rodrigodutra/dev/personal/office-presence && /usr/bin/bundle exec ruby bin/sync_to_firebase.rb >> logs/firebase_sync.log 2>&1
```

Create the logs directory:
```bash
mkdir -p logs
```

### Alternative: Run as a Service

For more reliable syncing, you can create a systemd service (Linux) or launchd service (macOS).

#### macOS (launchd) Example

Create `~/Library/LaunchAgents/com.officeprescence.firebase-sync.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.officepresence.firebase-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/bundle</string>
        <string>exec</string>
        <string>ruby</string>
        <string>bin/sync_to_firebase.rb</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/rodrigodutra/dev/personal/office-presence</string>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>StandardOutPath</key>
    <string>/Users/rodrigodutra/dev/personal/office-presence/logs/firebase_sync.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/rodrigodutra/dev/personal/office-presence/logs/firebase_sync_error.log</string>
</dict>
</plist>
```

Load the service:
```bash
launchctl load ~/Library/LaunchAgents/com.officeprescence.firebase-sync.plist
```

## Step 6: Monitor and Maintain

### View Logs

```bash
# Cron logs
tail -f logs/firebase_sync.log

# launchd logs
tail -f logs/firebase_sync.log logs/firebase_sync_error.log
```

### Check Firebase Console

1. Go to Firebase Console > Realtime Database
2. You should see a `dashboard` node with your data
3. Data should update every 5 minutes

### Verify Dashboard

Visit your Firebase-hosted dashboard: `https://your-project-id.web.app`

## Troubleshooting

### "No data available" on Dashboard

1. Check that sync script ran successfully: `bundle exec ruby bin/sync_to_firebase.rb`
2. Check Firebase Database in console - verify `dashboard` node exists
3. Check browser console for JavaScript errors
4. Verify Firebase config in `index.html` matches your project

### Sync Script Errors

1. Verify `.env.firebase` has correct `FIREBASE_DATABASE_URL`
2. Check database rules allow writes (temporarily set `.write: true` for testing)
3. Ensure your local Ruby server is running and populating SQLite

### Firebase Rules Denied

If you see "permission denied" errors:
1. Go to Firebase Console > Realtime Database > Rules
2. Temporarily set to test mode:
   ```json
   {
     "rules": {
       ".read": true,
       ".write": true
     }
   }
   ```
3. Test, then restore proper rules in `database.rules.json`

## Cost Considerations

Firebase free tier ("Spark Plan") includes:
- **Realtime Database**: 1 GB stored, 10 GB/month downloaded
- **Hosting**: 10 GB storage, 360 MB/day transferred

Your small dashboard data (~few KB) will easily stay within free limits.

## Security Notes

- The dashboard data is **publicly readable** (anyone with the URL can view)
- Only your sync script can write data
- If you need authentication, upgrade to Firebase Authentication and add login

## Updating the Dashboard

To update the dashboard design:
1. Edit `firebase_public/index.html`
2. Run `firebase deploy --only hosting`

To update sync logic:
1. Edit `bin/sync_to_firebase.rb`
2. The next cron run will use the updated script

## Benefits of This Setup

✅ No port forwarding needed  
✅ Dashboard accessible from anywhere  
✅ Free hosting on Firebase  
✅ Real-time updates (Firebase handles websockets)  
✅ Local server continues working normally  
✅ Minimal data usage (only JSON payloads)  

## Next Steps

- Customize the dashboard colors/layout in `firebase_public/index.html`
- Add your company logo
- Set up Firebase performance monitoring
- Consider adding authentication for private access
