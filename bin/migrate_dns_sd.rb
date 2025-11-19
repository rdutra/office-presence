#!/usr/bin/env ruby
# frozen_string_literal: true

# Migration Script: Add hostname and device_id columns to devices table
# This script ensures your database has the new columns for DNS-SD support

require "bundler/setup"
require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"

puts "=" * 60
puts "Database Migration: DNS-SD Support"
puts "=" * 60
puts ""

# Connect to database
db = OfficePresence::Database.connection

puts "Checking database schema..."
columns = db[:devices].columns

needs_hostname = !columns.include?(:hostname)
needs_device_id = !columns.include?(:device_id)

if !needs_hostname && !needs_device_id
  puts "✓ Database already has hostname and device_id columns"
  puts "✓ No migration needed"
  exit 0
end

puts "Adding missing columns..."

if needs_hostname
  puts "  Adding 'hostname' column..."
  db.alter_table(:devices) do
    add_column :hostname, String
  end
  puts "  ✓ Added 'hostname' column"
end

if needs_device_id
  puts "  Adding 'device_id' column..."
  db.alter_table(:devices) do
    add_column :device_id, String
  end
  puts "  ✓ Added 'device_id' column"
end

puts ""
puts "=" * 60
puts "✓ Migration completed successfully!"
puts "=" * 60
puts ""
puts "Next steps:"
puts "  1. Restart your server: ./bin/server_restart.sh"
puts "  2. The next scan will populate the new fields"
puts "  3. Devices will now be tracked by persistent identifiers"
puts ""
