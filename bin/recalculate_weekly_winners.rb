#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "date"
require "optparse"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"
require_relative "../lib/office_presence/models/attendance"
require_relative "../lib/office_presence/models/person"

options = {
  dry_run: false,
  week_start: nil
}

OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby bin/recalculate_weekly_winners.rb [options]"

  parser.on("--week-start DATE", "Recalculate a specific week (YYYY-MM-DD)") do |value|
    options[:week_start] = Date.parse(value).to_s
  rescue ArgumentError
    abort "Invalid --week-start value: #{value.inspect}"
  end

  parser.on("--dry-run", "Show planned changes without writing them") do
    options[:dry_run] = true
  end

  parser.on("-h", "--help", "Show help") do
    puts parser
    exit 0
  end
end.parse!

db = OfficePresence::Database.connection
attendance_model = OfficePresence::Models::Attendance.new(db)
weekly_winners = db[:weekly_winners]

unless db.table_exists?(:weekly_winners)
  puts "weekly_winners table does not exist"
  exit 0
end

def anonymous_winner?(winner)
  OfficePresence::Models::Person.anonymous_name?(winner[:person])
end

def winner_key(winner)
  winner[:person_key] || winner[:person_mac] || winner[:person]
end

def recompute_week(attendance_model, week_start:, week_end:, win_counts:)
  candidates = attendance_model.top_attendees_with_max_days(
    start_date: week_start,
    end_date: week_end
  )
  return nil if candidates.empty?

  if candidates.length == 1
    candidates.first
  else
    candidates.min_by do |candidate|
      [win_counts[winner_key(candidate)], candidate[:person].to_s.downcase]
    end
  end
end

def replacement_change(existing_winner, replacement)
  return nil unless replacement || existing_winner[:id]
  return { action: :delete, existing: existing_winner, replacement: nil } unless replacement

  changed = existing_winner[:id].nil? ||
    existing_winner[:person] != replacement[:person] ||
    existing_winner[:person_mac] != replacement[:person_key] ||
    existing_winner[:days] != replacement[:days]

  return nil unless changed

  {
    action: existing_winner[:id] ? :update : :insert,
    existing: existing_winner,
    replacement: replacement
  }
end

def apply_change!(weekly_winners, change)
  existing = change[:existing]
  replacement = change[:replacement]

  case change[:action]
  when :delete
    weekly_winners.where(id: existing[:id]).delete
  when :insert
    weekly_winners.insert(
      week_start: existing[:week_start],
      week_end: existing[:week_end],
      person: replacement[:person],
      person_mac: replacement[:person_key],
      days: replacement[:days]
    )
  when :update
    weekly_winners.where(id: existing[:id]).update(
      person: replacement[:person],
      person_mac: replacement[:person_key],
      days: replacement[:days]
    )
  end
end

def print_change(change)
  existing = change[:existing]
  replacement = change[:replacement]
  label = "#{existing[:week_start]}..#{existing[:week_end]}"

  case change[:action]
  when :delete
    puts "#{label}: deleting #{existing[:person].inspect} (no eligible mapped attendee remains)"
  when :insert
    puts "#{label}: inserting #{replacement[:person]} with #{replacement[:days]} day(s)"
  when :update
    puts "#{label}: #{existing[:person].inspect} -> #{replacement[:person].inspect} (#{replacement[:days]} day(s))"
  end
end

rows = weekly_winners.order(:week_start).all
changes = []

if options[:week_start]
  target_start = options[:week_start]
  target_row = rows.find { |row| row[:week_start] == target_start } || {
    id: nil,
    week_start: target_start,
    week_end: (Date.parse(target_start) + 6).to_s,
    person: nil,
    person_mac: nil,
    days: nil
  }

  win_counts = Hash.new(0)

  rows.each do |row|
    break if row[:week_start] >= target_start

    if anonymous_winner?(row)
      replacement = recompute_week(
        attendance_model,
        week_start: Date.parse(row[:week_start]),
        week_end: Date.parse(row[:week_end]),
        win_counts: win_counts
      )
      win_counts[winner_key(replacement)] += 1 if replacement
    else
      win_counts[winner_key(row)] += 1 if winner_key(row)
    end
  end

  replacement = recompute_week(
    attendance_model,
    week_start: Date.parse(target_row[:week_start]),
    week_end: Date.parse(target_row[:week_end]),
    win_counts: win_counts
  )
  change = replacement_change(target_row, replacement)
  changes << change if change
else
  win_counts = Hash.new(0)

  rows.each do |row|
    if anonymous_winner?(row)
      replacement = recompute_week(
        attendance_model,
        week_start: Date.parse(row[:week_start]),
        week_end: Date.parse(row[:week_end]),
        win_counts: win_counts
      )
      change = replacement_change(row, replacement)
      changes << change if change
      win_counts[winner_key(replacement)] += 1 if replacement
    else
      win_counts[winner_key(row)] += 1 if winner_key(row)
    end
  end
end

puts "=" * 60
puts options[:dry_run] ? "Weekly Winner Recalculation (dry run)" : "Weekly Winner Recalculation"
puts "=" * 60

if changes.empty?
  puts options[:week_start] ? "No change needed for week #{options[:week_start]}" : "No weekly winners need recalculation"
  exit 0
end

changes.each { |change| print_change(change) }

if options[:dry_run]
  puts "-" * 60
  puts "Dry run only. No rows were changed."
  exit 0
end

db.transaction do
  changes.each { |change| apply_change!(weekly_winners, change) }
end

puts "-" * 60
puts "Applied #{changes.length} change(s)"
