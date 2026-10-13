#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "date"
require "optparse"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"
require_relative "../lib/office_presence/models/attendance"
require_relative "../lib/office_presence/models/person"

options = { apply: false, week_start: nil, database: nil }
OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby bin/recalculate_weekly_winners.rb [--database PATH] [--week-start DATE] [--apply]"
  parser.on("--database PATH", "Use a specific SQLite database (default: app database)") do |value|
    options[:database] = value
  end
  parser.on("--week-start DATE", "Recalculate only this Monday (YYYY-MM-DD)") do |value|
    options[:week_start] = Date.parse(value)
  rescue ArgumentError
    abort "Invalid --week-start value: #{value.inspect}"
  end
  parser.on("--apply", "Apply the recalculation; default is report-only") { options[:apply] = true }
  parser.on("--dry-run", "Show planned changes without writing (default)") { options[:apply] = false }
  parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
end.parse!

db = if options[:database]
  Sequel.sqlite(File.expand_path(options[:database]))
else
  OfficePresence::Database.connection
end

unless db.table_exists?(:weekly_winners) && db.table_exists?(:attendance)
  abort "attendance and weekly_winners tables are required"
end
unless db[:weekly_winners].columns.include?(:user_id) && db.table_exists?(:person_mac_history)
  abort "Apply the user ID and MAC history migrations before recalculating winners"
end

attendance_model = OfficePresence::Models::Attendance.new(db)
weekly_winners = db[:weekly_winners]
existing_rows = weekly_winners.order(:week_start).all
rows_by_start = existing_rows.to_h { |row| [row[:week_start], row] }

def monday_of(date)
  date - (date.cwday - 1)
end

def winner_key(winner)
  winner && (winner[:user_id] || winner[:person_key] || winner[:person_mac])
end

def existing_winner_key(db, winner)
  return winner[:user_id] if winner[:user_id] && !winner[:user_id].empty?
  return nil if winner[:person_mac].to_s.empty?

  history = db[:person_mac_history].where(mac: winner[:person_mac]).all.select do |row|
    begins_before_week_ends = row[:first_seen_at].nil? || row[:first_seen_at][0, 10] <= winner[:week_end]
    ends_after_week_starts = row[:last_seen_at].nil? || row[:last_seen_at][0, 10] >= winner[:week_start]
    begins_before_week_ends && ends_after_week_starts
  end
  history_ids = history.map { |row| row[:user_id] }.uniq
  return history_ids.first if history_ids.length == 1

  current_person = db[:people].where(mac: winner[:person_mac]).first
  current_person&.[](:user_id) || winner[:person_mac]
end

def replacement_change(existing, replacement, week_start:, week_end:)
  return nil unless replacement

  current = existing || { id: nil, week_start: week_start.to_s, week_end: week_end.to_s }
  changed = current[:id].nil? ||
    current[:week_end] != week_end.to_s ||
    current[:person] != replacement[:person] ||
    current[:person_mac] != replacement[:person_key] ||
    current[:user_id] != replacement[:user_id] ||
    current[:days] != replacement[:days]
  return nil unless changed

  { action: current[:id] ? :update : :insert, existing: current, replacement: replacement }
end

def apply_change!(weekly_winners, change)
  existing = change[:existing]
  replacement = change[:replacement]
  attributes = {
    week_end: existing[:week_end],
    person: replacement[:person],
    person_mac: replacement[:person_key],
    user_id: replacement[:user_id],
    days: replacement[:days]
  }

  if change[:action] == :insert
    weekly_winners.insert(attributes.merge(week_start: existing[:week_start]))
  else
    weekly_winners.where(id: existing[:id]).update(attributes)
  end
end

def print_change(change)
  existing = change[:existing]
  replacement = change[:replacement]
  label = "#{existing[:week_start]}..#{existing[:week_end]}"
  action = change[:action] == :insert ? "insert" : "update"
  prior = existing[:person] ? "#{existing[:person]} -> " : ""
  puts "#{label}: #{action} #{prior}#{replacement[:person]} (#{replacement[:days]} day(s))"
end

def latest_week_with_data(db, existing_rows)
  dates = [db[:attendance].max(:date), existing_rows.map { |row| row[:week_end] }.compact.max].compact
  return nil if dates.empty?

  [monday_of(Date.parse(dates.max)), monday_of(Date.today) - 7].min
end

first_date_candidates = [db[:attendance].min(:date), existing_rows.map { |row| row[:week_start] }.compact.min].compact
if options[:week_start]
  target_starts = [options[:week_start]]
  abort "--week-start must be a Monday" unless options[:week_start].cwday == 1
  abort "--week-start must be in the past" if options[:week_start] >= monday_of(Date.today)
else
  abort "No attendance or winner data found" if first_date_candidates.empty?
  latest_week = latest_week_with_data(db, existing_rows)
  abort "No completed workweek exists in the database yet" unless latest_week
  first_week = monday_of(Date.parse(first_date_candidates.min))
  target_starts = (first_week..latest_week).step(7).to_a
end

target_set = target_starts.to_h { |date| [date.to_s, true] }
win_counts = Hash.new(0)
changes = []
tie_details = []

# Recompute earlier weeks too, so tie-break counts reflect the corrected
# identity-linked history before evaluating a requested specific week.
process_starts = if options[:week_start]
  first_date_candidates.empty? ? target_starts : (monday_of(Date.parse(first_date_candidates.min))..options[:week_start]).step(7).to_a
else
  target_starts
end

process_starts.each do |week_start|
  week_end = week_start + 4
  start_key = week_start.to_s
  existing = rows_by_start[start_key]
  candidates = attendance_model.top_attendees_with_max_days(start_date: week_start, end_date: week_end)

  if candidates.empty?
    # Preserve known winners when current mappings no longer expose historic
    # attendance rows. They still contribute to later tie-break counts.
    win_counts[existing_winner_key(db, existing)] += 1 if existing && existing_winner_key(db, existing)
    next
  end

  replacement = if candidates.length == 1
    candidates.first
  else
    ranked = candidates.map do |candidate|
      [candidate, win_counts[winner_key(candidate)] || 0]
    end
    if options[:week_start] && target_set[start_key]
      tie_details = ranked.map { |candidate, wins| "#{candidate[:person]}: #{wins}" }
    end
    ranked.min_by { |candidate, wins| [wins, candidate[:person].to_s.downcase] }.first
  end
  win_counts[winner_key(replacement)] += 1 if winner_key(replacement)

  next unless target_set[start_key]

  change = replacement_change(existing, replacement, week_start: week_start, week_end: week_end)
  changes << change if change
end

puts "Weekly Winner Recalculation (#{options[:apply] ? 'apply' : 'dry run'})"
puts "Weeks considered: #{target_starts.first}..#{target_starts.last} (#{target_starts.length})"
puts "Tie-break counts: #{tie_details.join(', ')}" unless tie_details.empty?
if changes.empty?
  puts "No changes needed"
  exit 0
end

changes.each { |change| print_change(change) }
if options[:apply]
  db.transaction { changes.each { |change| apply_change!(weekly_winners, change) } }
  puts "Applied #{changes.length} change(s)"
else
  puts "Dry run only. No rows were changed. Re-run with --apply to persist changes."
end
