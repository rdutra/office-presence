#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "digest"
require "json"
require "optparse"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"

options = { apply: false, json: false }
OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby bin/backfill_user_ids.rb [--apply] [--json]"
  parser.on("--apply", "Write confident assignments; default is report-only") { options[:apply] = true }
  parser.on("--json", "Print the report as JSON") { options[:json] = true }
  parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
end.parse!

db = OfficePresence::Database.connection
abort "people table does not exist" unless db.table_exists?(:people)
abort "user_id migration has not been applied to people" unless db[:people].columns.include?(:user_id)

people = db[:people].order(:mac).all
winners = db.table_exists?(:weekly_winners) ? db[:weekly_winners].order(:week_start).all : []
devices = db.table_exists?(:devices) ? db[:devices].all : []
devices_by_mac = devices.to_h { |device| [device[:mac], device] }
people_by_mac = people.to_h { |person| [person[:mac], person] }
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

  candidate_macs = candidates.map { |row| row[:mac] }.uniq
  resolved_ids = candidate_macs.map { |mac| people_resolution[mac] }.uniq
  if !candidates.empty? && !resolved_ids.include?(:ambiguous) && resolved_ids.length == 1 && resolved_ids.first
    winner_assignments << {
      table: "weekly_winners",
      key: { id: winner[:id] },
      week_start: winner[:week_start],
      person: winner[:person],
      person_mac: winner[:person_mac],
      user_id: resolved_ids.first,
      reason: direct_person ? "current_person_mac_match" : "device_id_match"
    }
  else
    reviews << {
      type: "unmatched_historical_winner",
      week_start: winner[:week_start],
      person: winner[:person],
      person_mac: winner[:person_mac],
      candidate_macs: candidate_macs,
      reason: candidates.empty? ? "no_current_person_or_device_match" : "ambiguous_or_unresolved_identity"
    }
  end
end

report = {
  mode: options[:apply] ? "apply" : "dry_run",
  people_assignments: assignments,
  winner_assignments: winner_assignments,
  review_required: reviews
}

if options[:apply]
  db.transaction do
    assignments.each do |assignment|
      db[assignment[:table].to_sym].where(assignment[:key]).where(user_id: nil).update(user_id: assignment[:user_id])
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
  reviews.each do |row|
    puts "  REVIEW #{row[:type]}: #{row.to_json}"
  end
  puts "No changes written. Re-run with --apply to persist confident assignments." unless options[:apply]
end
