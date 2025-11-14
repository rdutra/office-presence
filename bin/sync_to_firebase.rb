#!/usr/bin/env ruby
# frozen_string_literal: true

# Firebase Data Sync Script
# This script reads from the local SQLite database and pushes dashboard data to Firebase Realtime Database
# Run this periodically (e.g., every 5 minutes via cron) to keep the Firebase dashboard updated

require "bundler/setup"
require "json"
require "net/http"
require "net/https"
require "openssl"
require "uri"
require "dotenv"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"
require_relative "../lib/office_presence/models/presence"

# Load environment variables
Dotenv.load(".env.firebase")

# Firebase configuration
FIREBASE_DATABASE_URL = ENV["FIREBASE_DATABASE_URL"]
FIREBASE_SERVICE_ACCOUNT_PATH = ENV["FIREBASE_SERVICE_ACCOUNT_PATH"]

if FIREBASE_DATABASE_URL.nil? || FIREBASE_DATABASE_URL.empty?
  puts "ERROR: FIREBASE_DATABASE_URL not set in .env.firebase"
  exit 1
end

# Initialize database connection
db = OfficePresence::Database.connection
presence_model = OfficePresence::Models::Presence.new(db, present_window_minutes: 5)

# Get dashboard data
dashboard_data = presence_model.dashboard_data

# Add timestamp
dashboard_data[:last_updated] = Time.now.utc.iso8601

# Convert to JSON
json_data = JSON.generate(dashboard_data)

puts "=" * 60
puts "Firebase Sync - #{Time.now}"
puts "=" * 60
puts "Present: #{dashboard_data[:present_count]} / #{dashboard_data[:total_people]}"
puts "Mapped Present: #{dashboard_data[:mapped_present].length}"
puts "Mapped Absent: #{dashboard_data[:mapped_absent].length}"
puts "Top Attendees: #{dashboard_data[:top_attendees].length}"
puts "-" * 60

# Push to Firebase using REST API
# Firebase REST API allows writes with just the database URL
# Format: PUT https://[project-id].firebaseio.com/[path].json
uri = URI.parse("#{FIREBASE_DATABASE_URL}/dashboard.json")

begin
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  # Configure SSL to handle certificate verification on macOS
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  
  # Try to use system certificates, fall back to less strict verification if needed
  begin
    http.ca_file = "/etc/ssl/cert.pem" if File.exist?("/etc/ssl/cert.pem")
  rescue StandardError
    # If system certs aren't available, we'll use the default
  end
  
  request = Net::HTTP::Put.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request.body = json_data
  
  response = http.request(request)
  
  if response.code.to_i >= 200 && response.code.to_i < 300
    puts "✓ Successfully synced data to Firebase"
    puts "  Response: #{response.code} #{response.message}"
  else
    puts "✗ Failed to sync data to Firebase"
    puts "  Response: #{response.code} #{response.message}"
    puts "  Body: #{response.body}"
    exit 1
  end
rescue StandardError => e
  puts "✗ Error syncing to Firebase: #{e.message}"
  puts "  #{e.class}"
  puts e.backtrace.first(5)
  exit 1
end

puts "=" * 60
