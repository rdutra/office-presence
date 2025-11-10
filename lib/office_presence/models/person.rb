# frozen_string_literal: true

require "csv"
require_relative "../utils"

module OfficePresence
  module Models
    class Person
      attr_reader :db

      PEOPLE_CSV = File.join(__dir__, "../../../people.csv")

      def initialize(db)
        @db = db
      end

      def all
        db[:people].all
      end

      def count
        db[:people].count
      end

      def find_by_mac(mac)
        db[:people].where(mac: mac).first
      end

      def create_or_update(mac:, person:, device:, visible: true)
        db[:people].insert_conflict(
          target: :mac,
          update: { person: person, device: device, visible: visible }
        ).insert(
          mac: mac,
          person: person,
          device: device,
          visible: visible
        )
      end
      
      def toggle_visibility(mac:)
        person = find_by_mac(mac)
        return false unless person
        
        new_visibility = !person.fetch(:visible, true)
        db[:people].where(mac: mac).update(visible: new_visibility)
        new_visibility
      end
      
      def set_visibility(mac:, visible:)
        db[:people].where(mac: mac).update(visible: visible)
      end

      def load_from_csv
        return unless File.exist?(PEOPLE_CSV)
        
        db.transaction do
          db[:people].truncate
          CSV.foreach(PEOPLE_CSV, headers: true) do |row|
            mac = Utils.normalize_mac(row["mac_address"])
            next unless mac
            
            # Read visible from CSV, default to true if not present (backward compatibility)
            visible = row["visible"].nil? ? true : (row["visible"].downcase == "true")
            
            create_or_update(
              mac: mac,
              person: row["person"].to_s.strip,
              device: row["device"].to_s.strip,
              visible: visible
            )
          end
        end
      end

      def save_to_csv(mac:, person:, device:, visible: true)
        rows = []
        if File.exist?(PEOPLE_CSV)
          rows = CSV.read(PEOPLE_CSV, headers: true).map(&:to_h)
        end

        existing_index = rows.find_index { |r| Utils.normalize_mac(r["mac_address"]) == mac }
        
        if existing_index
          rows[existing_index] = { "mac_address" => mac, "person" => person, "device" => device, "visible" => visible.to_s }
        else
          rows << { "mac_address" => mac, "person" => person, "device" => device, "visible" => visible.to_s }
        end

        CSV.open(PEOPLE_CSV, "w") do |csv|
          csv << ["mac_address", "person", "device", "visible"]
          rows.each do |row|
            csv << [row["mac_address"], row["person"], row["device"], row.fetch("visible", "true")]
          end
        end
      end
    end
  end
end
