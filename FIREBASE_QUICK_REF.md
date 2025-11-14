# Firebase Dashboard - Quick Reference

## 🚀 Quick Start

```bash
# 1. Install Firebase CLI
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Create Firebase project at console.firebase.google.com
# - Enable Realtime Database
# - Get your Firebase config

# 4. Update configuration files
# - .firebaserc (project ID)
# - .env.firebase (Firebase config)
# - firebase_public/index.html (firebaseConfig object)

# 5. Deploy
firebase deploy

# 6. Test sync
bundle exec ruby bin/sync_to_firebase.rb

# 7. Set up cron (every 5 minutes)
crontab -e
# Add: */5 * * * * cd /path/to/office-presence && /usr/bin/bundle exec ruby bin/sync_to_firebase.rb >> logs/firebase_sync.log 2>&1
```

## 📁 Files Created

| File | Purpose |
|------|---------|
| `firebase.json` | Firebase project configuration |
| `.firebaserc` | Firebase project ID |
| `database.rules.json` | Database security rules (public read, no write) |
| `.env.firebase` | Firebase credentials (DO NOT COMMIT) |
| `firebase_public/index.html` | Static dashboard page |
| `bin/sync_to_firebase.rb` | Data sync script |
| `FIREBASE_SETUP.md` | Complete setup guide |

## 🔧 Common Commands

```bash
# Deploy everything
./bin/firebase_deploy.sh

# Deploy only hosting (dashboard HTML/CSS/JS changes)
./bin/firebase_deploy.sh --only hosting

# Deploy only database rules (security rule changes)
./bin/firebase_deploy.sh --only database

# Test sync script
bundle exec ruby bin/sync_to_firebase.rb

# View Firebase logs
firebase functions:log

# Open Firebase console
firebase open

# Open hosted dashboard in browser
firebase open hosting:site
```

## 🔍 Troubleshooting

```bash
# Check if sync is working
tail -f logs/firebase_sync.log

# Manually test sync
bundle exec ruby bin/sync_to_firebase.rb

# Check cron jobs
crontab -l

# View Firebase data
# Go to: https://console.firebase.google.com
# -> Realtime Database -> Check 'dashboard' node
```

## 📊 What Gets Synced

The sync script pushes this data to Firebase every 5 minutes:
- `mapped_present` - People currently in office
- `mapped_absent` - People who were in but left
- `present_count` - Number of people present
- `total_people` - Total team members
- `top_attendees` - Attendance leaderboard
- `last_updated` - Timestamp of last sync

## 🔒 Security

- Dashboard is **publicly readable** (anyone with URL can view)
- Only your sync script can **write** data
- Database rules defined in `database.rules.json`

## 💰 Costs

**Free Tier is Sufficient**
- Realtime Database: 1 GB storage, 10 GB/month downloads
- Hosting: 10 GB storage, 360 MB/day transfers
- Your dashboard: ~5 KB JSON updates every 5 minutes = ~2 MB/month

## 🌐 Your Dashboard URL

After deploying: `https://YOUR-PROJECT-ID.web.app`

## ⚡ How It Works

```
[Local Server] → (scans network) → [SQLite DB]
       ↓
[Sync Script] → (every 5 min) → [Firebase Realtime DB]
       ↓
[Firebase Hosting] ← (reads) ← [Users' Browsers]
```

## 🎨 Customization

To change dashboard appearance:
1. Edit `firebase_public/index.html`
2. Run `firebase deploy --only hosting`

## 📝 Next Steps

See `FIREBASE_SETUP.md` for complete documentation.
