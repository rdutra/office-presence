# Firebase Dashboard - Visual Overview

## 📊 Architecture Diagram

```
                     OFFICE NETWORK
    ┌─────────────────────────────────────────┐
    │                                         │
    │  📱 Devices (phones, laptops)           │
    │     ↓                                   │
    │  🔍 nmap scan (every 5 min)             │
    │     ↓                                   │
    │  💻 Ruby Server (Sinatra/Puma)          │
    │     ↓                                   │
    │  🗄️  SQLite Database                     │
    │     - devices table                     │
    │     - people table                      │
    │     - attendance table                  │
    └──────────────┬──────────────────────────┘
                   │
                   │ 🔄 bin/sync_to_firebase.rb
                   │    (cron: */5 * * * *)
                   │
                   ↓
         ☁️  FIREBASE CLOUD
    ┌──────────────────────────────────┐
    │  Firebase Realtime Database      │
    │  {                               │
    │    "dashboard": {                │
    │      "mapped_present": [...],    │
    │      "mapped_absent": [...],     │
    │      "present_count": 5,         │
    │      "total_people": 12,         │
    │      "top_attendees": [...],     │
    │      "last_updated": "..."       │
    │    }                             │
    │  }                               │
    └──────────────┬───────────────────┘
                   │
                   │ 📡 WebSocket (real-time)
                   │
                   ↓
    ┌──────────────────────────────────┐
    │  Firebase Hosting                │
    │  https://your-app.web.app        │
    │  └─ firebase_public/index.html   │
    └──────────────┬───────────────────┘
                   │
                   │ 🌐 HTTPS
                   │
                   ↓
         🌍 INTERNET USERS
    ┌──────────────────────────────────┐
    │  Any browser, anywhere           │
    │  - Office TV                     │
    │  - Home computer                 │
    │  - Mobile phone                  │
    │  - Tablet                        │
    └──────────────────────────────────┘
```

## 🔄 Data Flow Timeline

```
Time: 00:00  →  Local server scans network
              ↓
Time: 00:01  →  Devices detected, SQLite updated
              ↓
Time: 00:05  →  Cron triggers sync_to_firebase.rb
              ↓
Time: 00:05  →  Script reads SQLite → Firebase DB
              ↓
Time: 00:05  →  Firebase pushes update to all browsers (WebSocket)
              ↓
Time: 00:05  →  Dashboard updates instantly 🎉
              ↓
Time: 00:10  →  Process repeats...
```

## 📁 File Structure

```
office-presence/
├── 🔧 Configuration
│   ├── firebase.json              # Firebase config
│   ├── .firebaserc                # Project ID
│   ├── database.rules.json        # Security rules
│   └── .env.firebase              # Credentials (SECRET)
│
├── 🌐 Public Dashboard
│   └── firebase_public/
│       └── index.html             # Static dashboard page
│
├── 🔄 Sync Script
│   └── bin/
│       └── sync_to_firebase.rb    # SQLite → Firebase sync
│
├── 📚 Documentation
│   ├── FIREBASE_SETUP.md          # Complete guide
│   ├── FIREBASE_QUICK_REF.md      # Quick reference
│   ├── FIREBASE_IMPLEMENTATION.md # Summary
│   └── FIREBASE_VISUAL.md         # This file
│
├── 🛠️ Helper Scripts
│   └── setup_firebase.sh          # Interactive setup
│
└── 🏠 Local Server (unchanged)
    ├── lib/                       # Ruby app
    ├── views/                     # ERB templates
    ├── public/                    # Local assets
    └── data/                      # SQLite database
```

## 🔐 Security Model

```
┌─────────────────────────────────────────────────┐
│  Firebase Realtime Database Rules               │
├─────────────────────────────────────────────────┤
│                                                 │
│  dashboard/                                     │
│    ├── .read: true    ✅ Anyone can read        │
│    └── .write: false  ❌ No public writes       │
│                                                 │
│  Only your server can write via REST API        │
│  (using FIREBASE_DATABASE_URL)                  │
└─────────────────────────────────────────────────┘
```

## 💰 Cost Breakdown

```
Firebase Free Tier Limits:
┌─────────────────────────────────┐
│ Realtime Database               │
│  ✓ 1 GB stored                  │
│  ✓ 10 GB/month downloads        │
├─────────────────────────────────┤
│ Hosting                         │
│  ✓ 10 GB storage                │
│  ✓ 360 MB/day transfers         │
└─────────────────────────────────┘

Your Actual Usage:
┌─────────────────────────────────┐
│ Database                        │
│  ~ 5 KB per update              │
│  × 288 updates/day (5 min)      │
│  × 30 days                      │
│  = ~43 MB/month                 │
├─────────────────────────────────┤
│ Hosting                         │
│  ~ 50 KB HTML                   │
│  × estimated views              │
│  = minimal                      │
└─────────────────────────────────┘

Verdict: 🎉 FREE (well within limits)
```

## 🚀 Setup Steps (Visual)

```
Step 1: Install Firebase CLI
┌──────────────────────────┐
│ $ npm install -g         │
│   firebase-tools         │
└──────────────────────────┘
            ↓
Step 2: Create Firebase Project
┌──────────────────────────┐
│ console.firebase.google  │
│   .com                   │
│ ↳ Create Project         │
│ ↳ Enable Realtime DB     │
└──────────────────────────┘
            ↓
Step 3: Configure Credentials
┌──────────────────────────┐
│ Update:                  │
│ • .firebaserc            │
│ • .env.firebase          │
│ • index.html config      │
└──────────────────────────┘
            ↓
Step 4: Deploy
┌──────────────────────────┐
│ $ firebase deploy        │
└──────────────────────────┘
            ↓
Step 5: Test Sync
┌──────────────────────────┐
│ $ bundle exec ruby       │
│   bin/sync_to_firebase.rb│
└──────────────────────────┘
            ↓
Step 6: Set Up Cron
┌──────────────────────────┐
│ $ crontab -e             │
│ */5 * * * * ...sync...   │
└──────────────────────────┘
            ↓
Step 7: Enjoy! 🎉
┌──────────────────────────┐
│ https://your-app.web.app │
└──────────────────────────┘
```

## 🔧 Troubleshooting Flow

```
Problem: Dashboard shows "No data available"
    ↓
Check 1: Did sync script run?
    $ bundle exec ruby bin/sync_to_firebase.rb
    ├─ ✓ Success → Check 2
    └─ ✗ Error → Fix credentials in .env.firebase
              ↓
Check 2: Is data in Firebase?
    Open Firebase Console → Realtime Database
    ├─ ✓ See "dashboard" node → Check 3
    └─ ✗ No data → Verify local SQLite has data
              ↓
Check 3: Is config correct in HTML?
    Open firebase_public/index.html
    Verify firebaseConfig matches Firebase Console
    ├─ ✓ Matches → Check browser console for errors
    └─ ✗ Mismatch → Update config and redeploy
```

## 🎯 Success Checklist

```
✅ Firebase CLI installed
✅ Firebase project created
✅ Realtime Database enabled
✅ .firebaserc has correct project ID
✅ .env.firebase has all credentials
✅ firebase_public/index.html has correct config
✅ firebase deploy succeeded
✅ bin/sync_to_firebase.rb runs without errors
✅ Firebase Console shows "dashboard" data
✅ Dashboard loads at https://your-app.web.app
✅ Dashboard shows your team data
✅ Cron job set up for automatic sync
```

## 📞 Quick Commands Reference

```bash
# Deploy everything
firebase deploy

# Test sync manually
bundle exec ruby bin/sync_to_firebase.rb

# View logs
tail -f logs/firebase_sync.log

# Open Firebase Console
firebase open

# Open hosted dashboard
firebase open hosting:site

# View real-time logs
firebase functions:log
```

---

**Questions?** See `FIREBASE_SETUP.md` for detailed documentation.
