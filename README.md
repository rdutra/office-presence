# Ruby Office Presence

This directory contains a Ruby port of the office presence dashboard built with [Sinatra](https://sinatrarb.com/).

## Architecture

The application follows an MVC (Model-View-Controller) pattern:

### Models (`lib/office_presence/models/`)
- **Device** - Manages network devices (MAC, IP, last_seen)
- **Person** - Manages people and their registered devices
- **Attendance** - Tracks daily attendance records
- **Presence** - Service layer combining models for presence queries

### Views (`views/`)
- **index.erb** - Main registration page with device lists
- **dashboard.erb** - TV dashboard with real-time updates
- **partials/** - Reusable view components

### Controllers
- **WebApp** (`lib/office_presence/web_app.rb`) - Routes and API endpoints
- **Scanner** (`lib/office_presence/scanner.rb`) - Background network scanning

## Prerequisites

* Ruby 3.3+
* Bundler (`gem install bundler`)
* `nmap` and the system `arp` utility available on the host
* For DNS-SD device discovery: `sudo` access to run nmap (one-time setup)

## Setup

```bash
cd office-presence
cp .env.example .env   # optional – adjust values as needed
bundle install
bundle exec rake db:migrate

# Setup passwordless sudo for nmap (required for DNS-SD scanning)
./bin/setup_sudo_nmap.sh
```

Configuration and the SQLite database live inside this directory (`/.env`, `data/presence.sqlite`), leaving the Ruby app untouched.

### DNS-SD Device Discovery

The scanner uses **DNS Service Discovery** to identify devices with persistent identifiers (AirPlay Device ID, Bluetooth Address) instead of changing MAC addresses. This provides reliable device tracking even when devices roam between access points.

See [DNS_SD_DISCOVERY.md](DNS_SD_DISCOVERY.md) for details.

### Database Migrations

Migrations live in `db/migrations` and run via [Sequel](https://sequel.jeremyevans.net/). Common workflows:

```bash
# Apply all pending migrations (or specify VERSION=001)
bundle exec rake db:migrate

# Roll back one step (override STEPS=N)
bundle exec rake db:rollback

# Inspect the applied versions
bundle exec rake db:status
```

#### Creating a new migration

1. Decide on a descriptive name and version. We use zero-padded numbers (e.g. `002_add_presets.rb`) but timestamps work just as well.
2. Create the file inside `db/migrations`:
   ```bash
   VERSION=002
   touch "db/migrations/${VERSION}_add_presets.rb"
   ```
3. Implement the migration using Sequel's DSL:
   ```ruby
   # frozen_string_literal: true

   Sequel.migration do
     up do
       add_column :people, :timezone, String
     end

     down do
       drop_column :people, :timezone
     end
   end
   ```
4. Run `bundle exec rake db:migrate` to apply it locally and commit the migration file with the related code changes.

The application automatically runs pending migrations during boot, so manual invocations are mainly for local development or schema planning.

## Running

### Quick Start (Recommended)

Use the provided server management scripts to start both the web server and Firebase sync scheduler:

```bash
# Start all services (Puma + Firebase sync)
./bin/server_start.sh

# Check service status
./bin/server_status.sh

# Stop all services
./bin/server_stop.sh

# Restart all services
./bin/server_restart.sh
```

The startup script will:
- Start Puma web server on port 9292
- Start Firebase sync scheduler (syncs every 5 minutes)
- Create PID files in `tmp/pids/`
- Log output to `logs/`

### Manual Start

If you prefer to run services manually:

```bash
# Start Puma web server only
bundle exec puma -C config/puma.rb

# Start Firebase sync scheduler only (requires Firebase setup)
bundle exec ruby bin/firebase_scheduler.rb
```

The app starts a background scanner thread as soon as it boots. It honours the shared `SUBNETS`, `SCAN_INTERVAL`, and `PRESENT_WINDOW_MINUTES` environment variables.

**Local Dashboard:** [http://localhost:9292/dashboard](http://localhost:9292/dashboard)  
**Registration Page:** [http://localhost:9292](http://localhost:9292)

## Firebase Hosting (Cloud Dashboard)

Deploy a public-facing dashboard to Firebase Hosting that stays in sync with your local server:

### Features
- ☁️ **No port forwarding needed** - dashboard hosted on Firebase
- 🌐 **Accessible from anywhere** - public URL accessible globally
- 💰 **Free** - stays within Firebase free tier limits (~43 MB/month usage)
- 🔄 **Auto-sync** - data syncs from your local server every 5 minutes
- 📱 **Real-time updates** - Firebase pushes updates to all viewers instantly

### Architecture

```
Local Server (scans network) → SQLite Database
        ↓ (every 5 minutes)
Firebase Sync Scheduler → Firebase Realtime Database
        ↓ (real-time WebSocket)
Firebase Hosting → Users' Browsers
```

### Quick Setup

1. **Create Firebase Project:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create a new project
   - Enable Realtime Database

2. **Run Setup Script:**
   ```bash
   ./setup_firebase.sh
   ```
   This interactive script will guide you through the configuration.

3. **Configure Credentials:**
   - Update `.env.firebase` with your Firebase config (already done if you followed setup)

4. **Deploy:**
   ```bash
   # Deploy everything
   ./bin/firebase_deploy.sh
   
   # Or deploy selectively:
   ./bin/firebase_deploy.sh --only hosting    # Dashboard HTML only
   ./bin/firebase_deploy.sh --only database   # Security rules only
   ```

5. **Start Syncing:**
   The Firebase sync scheduler starts automatically when you run `./bin/server_start.sh`

### Firebase Documentation

- **[FIREBASE_SETUP.md](./FIREBASE_SETUP.md)** - Complete setup guide with troubleshooting
- **[FIREBASE_QUICK_REF.md](./FIREBASE_QUICK_REF.md)** - Quick reference card
- **[FIREBASE_VISUAL.md](./FIREBASE_VISUAL.md)** - Visual diagrams and flowcharts

### Manual Firebase Sync

If you prefer not to use the automatic scheduler:

```bash
# Run sync manually
bundle exec ruby bin/sync_to_firebase.rb

# Or set up a cron job (every 5 minutes)
crontab -e
# Add: */5 * * * * cd /path/to/office-presence && bundle exec ruby bin/sync_to_firebase.rb >> logs/firebase_sync.log 2>&1
```

### What Gets Synced

The sync scheduler pushes the following data to Firebase every 5 minutes:
- People currently in the office (with device info and status)
- People who were in earlier but have left
- Attendance statistics (present count, total team members)
- Top attendees leaderboard

**Your Firebase Dashboard URL:** `https://your-project-id.web.app`

### Requirements

**Local Server (running the sync):**
- ✅ Ruby with existing gems (no additional dependencies)
- ✅ `.env.firebase` configuration file
- ✅ Internet connection to reach Firebase

**Deployment Machine (one-time setup):**
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js and npm

The local server does **not** need Firebase CLI or Node.js - it uses simple HTTP REST API calls to sync data.
