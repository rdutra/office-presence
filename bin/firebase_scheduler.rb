#!/usr/bin/env ruby
# frozen_string_literal: true

# Firebase Sync Scheduler
# This script runs continuously and syncs data to Firebase every 5 minutes using rufus-scheduler

require "bundler/setup"
require "rufus-scheduler"
require "logger"

# Set up logging
LOG_DIR = File.expand_path("../logs", __dir__)
Dir.mkdir(LOG_DIR) unless Dir.exist?(LOG_DIR)

logger = Logger.new(File.join(LOG_DIR, "firebase_scheduler.log"), 10, 1024000)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, _progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

# Path to sync script
SYNC_SCRIPT = File.expand_path("sync_to_firebase.rb", __dir__)

logger.info "=" * 60
logger.info "Firebase Sync Scheduler starting..."
logger.info "Sync script: #{SYNC_SCRIPT}"
logger.info "Schedule: Every 5 minutes"
logger.info "=" * 60

# Create scheduler
scheduler = Rufus::Scheduler.new

# Run sync every 5 minutes
scheduler.every "5m", first: :now do
  logger.info "Triggering Firebase sync..."
  
  begin
    # Run the sync script
    output = `bundle exec ruby #{SYNC_SCRIPT} 2>&1`
    exit_status = $?.exitstatus
    
    if exit_status == 0
      logger.info "Sync completed successfully"
      # Log key metrics from output
      if output =~ /Present: (\d+) \/ (\d+)/
        logger.info "  └─ Present: #{$1} / #{$2}"
      end
    else
      logger.error "Sync failed with exit code #{exit_status}"
      logger.error "Output: #{output}"
    end
  rescue StandardError => e
    logger.error "Error running sync: #{e.message}"
    logger.error e.backtrace.first(3).join("\n")
  end
end

# Handle graceful shutdown
trap("INT") do
  logger.info "Received INT signal, shutting down..."
  scheduler.shutdown(:wait)
  logger.info "Scheduler stopped gracefully"
  exit 0
end

trap("TERM") do
  logger.info "Received TERM signal, shutting down..."
  scheduler.shutdown(:wait)
  logger.info "Scheduler stopped gracefully"
  exit 0
end

logger.info "Scheduler is running. Press Ctrl+C to stop."
logger.info "Next sync: #{scheduler.jobs.first.next_time}"
puts "Firebase Sync Scheduler started. Logging to #{File.join(LOG_DIR, 'firebase_scheduler.log')}"
puts "Press Ctrl+C to stop."

# Keep the script running
scheduler.join
