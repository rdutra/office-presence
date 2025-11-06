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

      def create_or_update(mac:, person:, device:)
        db[:people].insert_conflict(
          target: :mac,
          update: { person: person, device: device }
        ).insert(
          mac: mac,
          person: person,
          device: device
        )
      end

      def load_from_csv
        return unless File.exist?(PEOPLE_CSV)
        
        db.transaction do
          db[:people].truncate
          CSV.foreach(PEOPLE_CSV, headers: true) do |row|
            mac = Utils.normalize_mac(row["mac_address"])
            next unless mac
            
            create_or_update(
              mac: mac,
              person: row["person"].to_s.strip,
              device: row["device"].to_s.strip
            )
          end
        end
      end

      def save_to_csv(mac:, person:, device:)
        rows = []
        if File.exist?(PEOPLE_CSV)
          rows = CSV.read(PEOPLE_CSV, headers: true).map(&:to_h)
        end

        existing_index = rows.find_index { |r| Utils.normalize_mac(r["mac_address"]) == mac }
        
        if existing_index
          rows[existing_index] = { "mac_address" => mac, "person" => person, "device" => device }
        else
          rows << { "mac_address" => mac, "person" => person, "device" => device }
        end

        CSV.open(PEOPLE_CSV, "w") do |csv|
          csv << ["mac_address", "person", "device"]
          rows.each do |row|
            csv << [row["mac_address"], row["person"], row["device"]]
          end
        end
      end
    end
  end
end
