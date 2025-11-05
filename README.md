# Ruby Office Presence

This directory contains a Ruby port of the office presence dashboard built with [Sinatra](https://sinatrarb.com/).

## Prerequisites

* Ruby 3.2+
* Bundler (`gem install bundler`)
* `nmap` and the system `arp` utility available on the host

## Setup

```bash
cd office-presence
cp .env.example .env   # optional – adjust values as needed
bundle install
```

Configuration, device mappings, and the SQLite database live inside this directory (`/.env`, `people.csv`, `data/presence.sqlite`), leaving the Ruby app untouched.

## Running

```bash
bundle exec puma -C config/puma.rb
```

The app starts a background scanner thread as soon as it boots. It honours the shared `SUBNETS`, `SCAN_INTERVAL`, and `PRESENT_WINDOW_MINUTES` environment variables.

Visit [http://localhost:9292](http://localhost:9292) (or the port shown in the Rack output) to view the dashboard.

