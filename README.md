# Ruby Office Presence

This directory contains a Ruby port of the office presence dashboard built with [Sinatra](https://sinatrarb.com/).

## Prerequisites

* Ruby 3.2+
* Bundler (`gem install bundler`)
* `nmap` and the system `arp` utility available on the host

## Setup

```bash
cd ruby_app
cp .env.example .env   # optional – adjust values as needed
bundle install
```

Configuration, device mappings, and the SQLite database live inside this directory (`ruby_app/.env`, `ruby_app/people.csv`, `ruby_app/data/presence.sqlite`), leaving the Python app untouched.

## Running

```bash
bundle exec rackup
```

The app starts a background scanner thread as soon as it boots. It honours the shared `SUBNETS`, `SCAN_INTERVAL`, and `PRESENT_WINDOW_MINUTES` environment variables.

Visit [http://localhost:9292](http://localhost:9292) (or the port shown in the Rack output) to view the dashboard.

## Notes

* The scanner stores results in `data/presence.sqlite`, keeping schema compatibility with the original app.
* Because scans invoke external utilities, make sure the process has the same permissions as the Python version (you may still need `sudo` for richer `nmap` output).
* The Sinatra view is a direct port of the Jinja template so the UI remains identical.
