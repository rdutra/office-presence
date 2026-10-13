#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "json"
require "optparse"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"

# Reviewed historical-to-current MAC mappings confirmed for the production
# database. Keep these explicit: display names alone are not identity proof.
REVIEWED_MAC_ALIASES = {
  "0a:fe:18:f3:b2:9d" => "b6:e6:9f:ff:a9:7c", # Pancho
  "42:e8:8e:d3:5d:06" => "b6:b8:71:e2:39:10", # Fernando Casalongue
  "b2:4a:5d:09:f5:b7" => "b6:b8:71:e2:39:10", # Fernando Casalongue
  "7a:15:06:5b:e6:e9" => "b6:b8:71:e2:39:10", # Fernando Casalongue
  "36:fb:ee:da:c0:40" => "b6:b8:71:e2:39:10", # Fernando Casalongue
  "6a:4c:a3:ba:77:9c" => "ca:2f:4b:fd:fe:cb", # Flor
  "26:11:ed:28:03:2b" => "62:5a:18:9d:66:b0"  # Rodrigo Dutra
}.freeze

options = { apply: false, database: nil, json: false }
OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby bin/fix_historical_winner_user_ids.rb [--database PATH] [--apply] [--json]"
  parser.on("--database PATH", "Use a specific SQLite database (default: app database)") do |value|
    options[:database] = value
  end
  parser.on("--apply", "Apply the reviewed mappings; default is report-only") do
    options[:apply] = true
  end
  parser.on("--json", "Print the report as JSON") { options[:json] = true }
  parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
end.parse!

db = if options[:database]
  Sequel.sqlite(File.expand_path(options[:database]))
else
  OfficePresence::Database.connection
end

required_tables = %i[people weekly_winners person_mac_history]
missing_tables = required_tables.reject { |table| db.table_exists?(table) }
abort "Required schema is missing #{missing_tables.join(', ')}; run the app migrations first" unless missing_tables.empty?

unless db[:people].columns.include?(:user_id) && db[:weekly_winners].columns.include?(:user_id)
  abort "user_id columns are missing; run the user ID migration and backfill first"
end

def date_part(value)
  value&.to_s&.slice(0, 10)
end

def earliest_date(*values)
  values.compact.min_by { |value| date_part(value) }
end

def latest_date(*values)
  values.compact.max_by { |value| date_part(value) }
end

changes = REVIEWED_MAC_ALIASES.map do |historical_mac, current_mac|
  person = db[:people].where(mac: current_mac).first
  winners = db[:weekly_winners].where(person_mac: historical_mac).order(:week_start).all
  conflicts = []

  if person.nil? || person[:user_id].to_s.empty?
    conflicts << "current MAC has no person with a user_id"
  end

  winners.each do |winner|
    if person && !winner[:user_id].to_s.empty? && winner[:user_id] != person[:user_id]
      conflicts << "winner #{winner[:week_start]} already belongs to user_id #{winner[:user_id]}"
    end
  end

  existing_history = if person
    db[:person_mac_history].where(user_id: person[:user_id], mac: historical_mac).first
  end
  existing_owner = db[:person_mac_history].where(mac: historical_mac)
    .exclude(user_id: person&.[](:user_id)).all
  if existing_owner.any?
    conflicts << "historical MAC already has another user_id in history"
  end

  first_seen = earliest_date(existing_history&.[](:first_seen_at), winners.first&.[](:week_start))
  last_seen = latest_date(existing_history&.[](:last_seen_at), winners.last&.[](:week_end))
  attendance_rows = if db.table_exists?(:attendance) && db[:attendance].columns.include?(:user_id)
    rows = db[:attendance].where(mac: historical_mac).where(Sequel.|({ user_id: nil }, { user_id: "" }))
    rows = rows.where(Sequel[:date] >= date_part(first_seen)) if first_seen
    rows = rows.where(Sequel[:date] <= date_part(last_seen)) if last_seen
    rows.count
  else
    0
  end

  {
    historical_mac: historical_mac,
    current_mac: current_mac,
    person: person&.[](:person),
    user_id: person&.[](:user_id),
    weeks: winners.map { |winner| winner[:week_start] },
    winners_to_update: winners.count { |winner| winner[:user_id].to_s.empty? },
    attendance_rows_to_update: attendance_rows,
    history_action: existing_history ? "update" : "insert",
    first_seen_at: first_seen,
    last_seen_at: last_seen,
    conflicts: conflicts.uniq
  }
end

if options[:apply]
  db.transaction do
    changes.each do |change|
      next unless change[:conflicts].empty? && change[:user_id]

      db[:weekly_winners]
        .where(person_mac: change[:historical_mac])
        .where(Sequel.|({ user_id: nil }, { user_id: "" }))
        .update(user_id: change[:user_id])

      if db.table_exists?(:attendance) && db[:attendance].columns.include?(:user_id)
        rows = db[:attendance].where(mac: change[:historical_mac]).where(Sequel.|({ user_id: nil }, { user_id: "" }))
        rows = rows.where(Sequel[:date] >= date_part(change[:first_seen_at])) if change[:first_seen_at]
        rows = rows.where(Sequel[:date] <= date_part(change[:last_seen_at])) if change[:last_seen_at]
        rows.update(user_id: change[:user_id])
      end

      db[:person_mac_history].insert_conflict(
        target: [:user_id, :mac],
        update: {
          first_seen_at: change[:first_seen_at],
          last_seen_at: change[:last_seen_at],
          source: "reviewed_alias"
        }
      ).insert(
        user_id: change[:user_id],
        mac: change[:historical_mac],
        first_seen_at: change[:first_seen_at],
        last_seen_at: change[:last_seen_at],
        source: "reviewed_alias"
      )
    end
  end
end

report = {
  mode: options[:apply] ? "apply" : "dry_run",
  database: options[:database] && File.expand_path(options[:database]),
  mappings: changes,
  winner_rows_to_update: changes.sum { |change| change[:conflicts].empty? ? change[:winners_to_update] : 0 },
  attendance_rows_to_update: changes.sum { |change| change[:conflicts].empty? ? change[:attendance_rows_to_update] : 0 },
  conflicts: changes.count { |change| !change[:conflicts].empty? }
}

if options[:json]
  puts JSON.pretty_generate(report)
else
  puts "Historical winner user ID repair (#{report[:mode]})"
  puts "Winner rows to update: #{report[:winner_rows_to_update]}"
  puts "Attendance rows to update: #{report[:attendance_rows_to_update]}"
  puts "Mappings with conflicts: #{report[:conflicts]}"
  changes.each do |change|
    state = change[:conflicts].empty? ? "#{change[:winners_to_update]} winner(s)" : "CONFLICT: #{change[:conflicts].join('; ')}"
    puts "  #{change[:historical_mac]} -> #{change[:current_mac]} (#{change[:person] || 'unknown'}, #{change[:weeks].join(', ')}) — #{state}"
  end
  puts "No changes written. Re-run with --apply to persist the reviewed mappings." unless options[:apply]
end
