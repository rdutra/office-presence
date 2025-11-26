# frozen_string_literal: true

require "bundler/setup"
require "rake"
require "sequel"
require "sequel/extensions/migration"

require_relative "lib/office_presence"
require_relative "lib/office_presence/database"

module DatabaseTasks
  module_function

  def migration_versions
    return [] unless Dir.exist?(OfficePresence::MIGRATIONS_DIR)

    Dir.children(OfficePresence::MIGRATIONS_DIR)
      .select { |file| file =~ /^\d+/ }
      .map { |file| file.split("_").first.to_i }
      .sort
  end
end

namespace :db do

  desc "Migrate the database (use VERSION=number to target a specific version)"
  task :migrate do
    target = ENV["VERSION"]&.to_i
    db = OfficePresence::Database.connection
    OfficePresence::Database.run_migrations(db, target: target)
    puts "Database migrated to #{target || 'latest'}"
  end

  desc "Rollback the database (use STEPS=N, default 1)"
  task :rollback do
    steps = (ENV["STEPS"] || "1").to_i
    raise "STEPS must be >= 1" if steps < 1

    db = OfficePresence::Database.connection
    current_version = Sequel::Migrator.current(db, OfficePresence::MIGRATIONS_DIR)
    versions = DatabaseTasks.migration_versions

    if versions.empty? || current_version.nil? || current_version.zero?
      puts "No migrations have been applied"
      next
    end

    current_index = versions.index(current_version) || versions.length - 1
    target_index = current_index - steps
    target_version = target_index >= 0 ? versions[target_index] : 0

    OfficePresence::Database.run_migrations(db, target: target_version)
    puts "Rolled back to version #{target_version}"
  end

  desc "Show migration status"
  task :status do
    db = OfficePresence::Database.connection
    current_version = Sequel::Migrator.current(db, OfficePresence::MIGRATIONS_DIR)
    versions = DatabaseTasks.migration_versions

    if versions.empty?
      puts "No migrations found in #{OfficePresence::MIGRATIONS_DIR}"
      next
    end

    puts "Current version: #{current_version || 0}"
    versions.each do |version|
      state = version <= (current_version || 0) ? "up" : "down"
      puts format("%5d %s", version, state)
    end
  end
end
