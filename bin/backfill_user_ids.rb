#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "digest"
require "json"
require "optparse"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"

options = { apply: false, json: false, database: nil, mac_aliases: {} }
OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby bin/backfill_user_ids.rb [--database PATH] [--mac-alias OLD=NEW] [--apply] [--json]"
  parser.on("--apply", "Write confident assignments; default is report-only") { options[:apply] = true }
  parser.on("--json", "Print the report as JSON") { options[:json] = true }
  parser.on("--database PATH", "Use a specific SQLite database") { |value| options[:database] = value }
  parser.on("--mac-alias OLD=NEW", "Resolve a reviewed historical MAC to its current MAC") do |value|
    old_mac, current_mac = value.split("=", 2).map { |mac| OfficePresence::Utils.normalize_mac(mac) }
    abort "Invalid --mac-alias value: #{value.inspect}" unless old_mac && current_mac
    options[:mac_aliases][old_mac] = current_mac
  end
  parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
end.parse!

db = if options[:database]
  database = Sequel.sqlite(File.expand_path(options[:database]))
  OfficePresence::Database.run_migrations(database)
  database
else
  OfficePresence::Database.connection
end
abort "people table does not exist" unless db.table_exists?(:people)
abort "user_id migration has not been applied to people" unless db[:people].columns.include?(:user_id)

people = db[:people].order(:mac).all
winners = db.table_exists?(:weekly_winners) ? db[:weekly_winners].order(:week_start).all : []
devices = db.table_exists?(:devices) ? db[:devices].all : []
devices_by_mac = devices.to_h { |device| [device[:mac], device] }
people_by_mac = people.to_h { |person| [person[:mac], person] }
mac_history_by_mac = db.table_exists?(:person_mac_history) ? db[:person_mac_history].all.group_by { |row| row[:mac] } : {}
people_by_device_id = people.reject { |person| person[:device_id].to_s.empty? }
                             .group_by { |person| person[:device_id] }

def deterministic_user_id(identity_type, value)
  # Version-5-shaped UUID derived from an identity key, so report-only runs
  # produce the same proposed IDs and an interrupted apply can be retried.
  bytes = Digest::SHA256.digest("office-presence:user:v1:#{identity_type}:#{value}").bytes.first(16)
  bytes[6] = (bytes[6] & 0x0f) | 0x50
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  hex = bytes.pack("C*").unpack1("H*")
  [hex[0, 8], hex[8, 4], hex[12, 4], hex[16, 4], hex[20, 12]].join("-")
end

def normalized_person_name(person)
  person[:person].to_s.strip.downcase
end

assignments = []
reviews = []
people_resolution = {}

# Resolve device identity groups first. Repeated device IDs are joined only
# when their current person labels agree and their existing IDs do not conflict.
people_by_device_id.each do |device_id, rows|
  names = rows.map { |row| normalized_person_name(row) }.uniq
  existing_ids = rows.map { |row| row[:user_id] }.compact.uniq

  if names.length > 1 || existing_ids.length > 1
    reviews << {
      type: "ambiguous_device_identity",
      device_id: device_id,
      macs: rows.map { |row| row[:mac] },
      names: rows.map { |row| row[:person] }.uniq,
      existing_user_ids: existing_ids
    }
    rows.each { |row| people_resolution[row[:mac]] = :ambiguous }
    next
  end

  user_id = existing_ids.first || deterministic_user_id("device", device_id)
  rows.each do |row|
    people_resolution[row[:mac]] = user_id
    next if row[:user_id]

    assignments << {
      table: "people",
      key: { mac: row[:mac] },
      user_id: user_id,
      reason: rows.length > 1 ? "same_device_id_and_person_label" : "unique_device_id"
    }
  end
end

# A record without a persistent device identifier receives its own ID. This
# does not merge it with similarly named people or claim continuity across MACs.
people.select { |row| row[:device_id].to_s.empty? }.each do |row|
  people_resolution[row[:mac]] = row[:user_id] || deterministic_user_id("mac", row[:mac])
  next if row[:user_id]

  assignments << {
    table: "people",
    key: { mac: row[:mac] },
    user_id: people_resolution[row[:mac]],
    reason: "standalone_record_no_device_id"
  }
end

winner_assignments = []
winners.each do |winner|
  next if winner[:user_id]

  candidates = []
  direct_person = people_by_mac[winner[:person_mac]] unless winner[:person_mac].to_s.empty?
  candidates << direct_person if direct_person

  # If the stored MAC is historical, use the device table only when it still
  # maps that MAC to a device_id and that ID resolves unambiguously to people.
  if candidates.empty? && !winner[:person_mac].to_s.empty?
    device = devices_by_mac[winner[:person_mac]]
    if device && !device[:device_id].to_s.empty?
      candidates = people_by_device_id.fetch(device[:device_id], [])
    end
  end

  aliased_person = nil
  if candidates.empty? && (current_mac = options[:mac_aliases][winner[:person_mac]])
    aliased_person = people_by_mac[current_mac]
    candidates << aliased_person if aliased_person
  end

  candidate_macs = candidates.map { |row| row[:mac] }.uniq
  resolved_ids = candidate_macs.map { |mac| people_resolution[mac] }.uniq
  history_matches = mac_history_by_mac.fetch(winner[:person_mac], []).select do |history|
    begins_before_week_ends = history[:first_seen_at].nil? || history[:first_seen_at][0, 10] <= winner[:week_end]
    ends_after_week_starts = history[:last_seen_at].nil? || history[:last_seen_at][0, 10] >= winner[:week_start]
    begins_before_week_ends && ends_after_week_starts
  end
  history_ids = history_matches.map { |row| row[:user_id] }.uniq
  resolved_id = if !candidates.empty? && !resolved_ids.include?(:ambiguous) && resolved_ids.length == 1
    resolved_ids.first
  elsif candidates.empty? && history_ids.length == 1
    history_ids.first
  end

  if resolved_id
    winner_assignments << {
      table: "weekly_winners",
      key: { id: winner[:id] },
      week_start: winner[:week_start],
      person: winner[:person],
      person_mac: winner[:person_mac],
      user_id: resolved_id,
      reason: if direct_person
        "current_person_mac_match"
      elsif aliased_person
        "reviewed_mac_alias"
      elsif candidates.empty?
        "mac_history_match"
      else
        "device_id_match"
      end
    }
  else
    reviews << {
      type: "unmatched_historical_winner",
      week_start: winner[:week_start],
      person: winner[:person],
      person_mac: winner[:person_mac],
      candidate_macs: candidate_macs,
      candidate_user_ids: history_ids,
      reason: candidates.empty? && history_ids.empty? ? "no_current_person_or_device_match" : "ambiguous_or_unresolved_identity"
    }
  end
end

mac_alias_history = options[:mac_aliases].map do |old_mac, current_mac|
  person = people_by_mac[current_mac]
  user_id = people_resolution[current_mac] || person&.[](:user_id)
  alias_winners = winners.select { |winner| winner[:person_mac] == old_mac }
  {
    old_mac: old_mac,
    current_mac: current_mac,
    user_id: user_id,
    first_seen_at: alias_winners.map { |winner| winner[:week_start] }.min,
    last_seen_at: alias_winners.map { |winner| winner[:week_end] }.max,
    reason: person && user_id ? "reviewed_mac_alias" : "current_mac_not_resolved"
  }
end

report = {
  mode: options[:apply] ? "apply" : "dry_run",
  database: options[:database] && File.expand_path(options[:database]),
  people_assignments: assignments,
  winner_assignments: winner_assignments,
  mac_alias_history: mac_alias_history,
  review_required: reviews
}

if options[:apply]
  db.transaction do
    assignments.each do |assignment|
      db[assignment[:table].to_sym].where(assignment[:key]).where(user_id: nil).update(user_id: assignment[:user_id])
    end

    people.each do |person|
      user_id = people_resolution[person[:mac]]
      next if user_id.nil? || user_id == :ambiguous

      attendance = db[:attendance].where(mac: person[:mac])
      first_seen = attendance.min(:first_seen_utc)
      last_seen = attendance.max(:last_seen_utc)
      last_seen ||= devices_by_mac.dig(person[:mac], :last_seen_utc)
      db[:person_mac_history].insert_conflict(
        target: [:user_id, :mac],
        update: { last_seen_at: last_seen, source: "user_id_backfill" }
      ).insert(
        user_id: user_id,
        mac: person[:mac],
        first_seen_at: first_seen,
        last_seen_at: last_seen,
        source: "user_id_backfill"
      )
      if db[:attendance].columns.include?(:user_id)
        db[:attendance].where(mac: person[:mac]).where(Sequel.|({ user_id: nil }, { user_id: "" })).update(user_id: user_id)
      end
    end

    mac_alias_history.each do |history|
      next unless history[:user_id]

      db[:person_mac_history].insert_conflict(
        target: [:user_id, :mac],
        update: { last_seen_at: history[:last_seen_at], source: "reviewed_alias" }
      ).insert(
        user_id: history[:user_id],
        mac: history[:old_mac],
        first_seen_at: history[:first_seen_at],
        last_seen_at: history[:last_seen_at],
        source: "reviewed_alias"
      )
    end

    winner_assignments.each do |assignment|
      db[:weekly_winners].where(id: assignment[:key][:id]).where(user_id: nil).update(user_id: assignment[:user_id])
    end
  end
end

if options[:json]
  puts JSON.pretty_generate(report)
else
  puts "User ID backfill (#{report[:mode]})"
  puts "People assignments: #{assignments.length}"
  puts "Historical winner assignments: #{winner_assignments.length}"
  puts "Records requiring review: #{reviews.length}"
  assignments.each do |row|
    puts "  person #{row[:key][:mac]} -> #{row[:user_id]} (#{row[:reason]})"
  end
  winner_assignments.each do |row|
    puts "  winner #{row[:week_start]} #{row[:person].inspect} -> #{row[:user_id]} (#{row[:reason]})"
  end
  mac_alias_history.each do |row|
    puts "  MAC alias #{row[:old_mac]} -> #{row[:current_mac]} for #{row[:user_id] || 'UNRESOLVED'} (#{row[:reason]})"
  end
  reviews.each do |row|
    puts "  REVIEW #{row[:type]}: #{row.to_json}"
  end
  puts "No changes written. Re-run with --apply to persist confident assignments." unless options[:apply]
end
