#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"

require_relative "../lib/office_presence"
require_relative "../lib/office_presence/database"
require_relative "../lib/office_presence/models/person"

path = File.join(OfficePresence::ROOT, "people.csv")

unless File.exist?(path)
  warn "No people.csv file found at #{path}"
  exit 1
end

db = OfficePresence::Database.connection
person_model = OfficePresence::Models::Person.new(db)

imported = 0
CSV.foreach(path, headers: true) do |row|
  mac = OfficePresence::Utils.normalize_mac(row["mac_address"])
  next unless mac

  visible = row["visible"].nil? ? true : row["visible"].to_s.strip.downcase == "true"

  person_model.create_or_update(
    mac: mac,
    person: row["person"].to_s.strip,
    device: row["device"].to_s.strip,
    visible: visible
  )

  imported += 1
end

puts "Imported #{imported} registration#{imported == 1 ? '' : 's'} into the database."
puts "You can now remove #{path}."
