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

## Setup

```bash
cd office-presence
cp .env.example .env   # optional – adjust values as needed
bundle install
```

Configuration, device mappings, and the SQLite database live inside this directory (`/.env`, `people.csv`, `data/presence.sqlite`), leaving the Ruby app untouched.

### People CSV Format

The `people.csv` file maps MAC addresses to people and optionally controls visibility:

```csv
mac_address,person,device,visible
aa:bb:cc:dd:ee:ff,John Doe,Laptop,true
11:22:33:44:55:66,Jane Smith,Phone,false
```

- **mac_address** - Device MAC address (required)
- **person** - Person's name (required)
- **device** - Device name/description (optional)
- **visible** - Whether to show on presence list (optional, defaults to `true`)

The `visible` column allows you to keep devices mapped for tracking while hiding them from public view - useful for users with multiple devices.

## Running

```bash
bundle exec puma -C config/puma.rb
```

The app starts a background scanner thread as soon as it boots. It honours the shared `SUBNETS`, `SCAN_INTERVAL`, and `PRESENT_WINDOW_MINUTES` environment variables.

Visit [http://localhost:9292](http://localhost:9292) (or the port shown in the Rack output) to view the dashboard.


