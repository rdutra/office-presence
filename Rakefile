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
    migrations.map(&:first)
  end

  def current_version(db)
    return nil unless db.table_exists?(:schema_info)

    db[:schema_info].get(:version) || 0
  rescue Sequel::DatabaseError
    nil
  end

  def migrations
    return [] unless Dir.exist?(OfficePresence::MIGRATIONS_DIR)

    Dir.children(OfficePresence::MIGRATIONS_DIR)
      .select { |file| file.match?(/^\d+/) }
      .map { |file| [file.split("_").first.to_i, file] }
      .sort_by(&:first)
  end
end

namespace :db do

  desc "Migrate the database (use VERSION=number to target a specific version)"
  task :migrate do
    target = ENV["VERSION"]&.to_i
    db = OfficePresence::Database.connection
    migrations = DatabaseTasks.migrations
    versions = migrations.map(&:first)

    if versions.empty?
      puts "No migrations found in #{OfficePresence::MIGRATIONS_DIR}"
      next
    end

    current_version = DatabaseTasks.current_version(db) || 0
    target_version = target || versions.last

    if current_version == target_version
      puts "Database already at version #{current_version}"
    elsif target_version > current_version
      pending = migrations.select { |version, _| version > current_version && version <= target_version }
      if pending.empty?
        puts "No new migrations to apply"
      else
        puts "Applying migrations:"
        pending.each { |version, file| puts format("  -> %s (up to %d)", file, version) }
      end
    else
      reverting = migrations.select { |version, _| version <= current_version && version > target_version }.reverse
      if reverting.empty?
        puts "No migrations to rollback"
      else
        puts "Reverting migrations:"
        reverting.each { |version, file| puts format("  -> %s (down to %d)", file, version - 1) }
      end
    end

    OfficePresence::Database.run_migrations(db, target: target)
    puts "Database migrated to #{target || 'latest'}"
  end

  desc "Rollback the database (use STEPS=N, default 1)"
  task :rollback do
    steps = (ENV["STEPS"] || "1").to_i
    raise "STEPS must be >= 1" if steps < 1

    db = OfficePresence::Database.connection
    current_version = DatabaseTasks.current_version(db)
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
    current_version = DatabaseTasks.current_version(db)
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
