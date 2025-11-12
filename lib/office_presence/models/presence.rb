# frozen_string_literal: true

require_relative "device"
require_relative "person"
require_relative "attendance"

module OfficePresence
  module Models
    class Presence
      attr_reader :device_model, :person_model, :attendance_model, :present_window_minutes

      # Status thresholds (in seconds)
      ACTIVE_THRESHOLD = 20      # Device responded to recent ping

      def initialize(db, present_window_minutes: 5)
        @device_model = Device.new(db)
        @person_model = Person.new(db)
        @attendance_model = Attendance.new(db)
        @present_window_minutes = present_window_minutes
      end

      # Calculate device status based on last_seen timestamp
      def calculate_status(last_seen_utc)
        return 'calculating' unless last_seen_utc

        begin
          last_seen = Time.parse(last_seen_utc)
        rescue ArgumentError
          return 'calculating'
        end

        diff_seconds = Time.now.utc - last_seen

        if diff_seconds < ACTIVE_THRESHOLD
          'active'
        else
          'inactive'
        end
      end

      # Enrich device records with calculated status
      def enrich_with_status(devices)
        devices.map do |device|
          device.merge(status: calculate_status(device[:last_seen_utc]))
        end
      end

      def mapped_devices
        devices = device_model.db[:devices]
          .join(:people, mac: :mac)
          .where(Sequel[:people][:visible] => true)
          .select_all(:devices)
          .select_append(Sequel[:people][:person], Sequel[:people][:device].as(:device_name))
          .order(Sequel.desc(:last_seen_utc))
          .all
          .map do |row|
            {
              person: row[:person],
              device: row[:device_name],
              mac: row[:mac],
              ip: row[:ip],
              hostname: row[:hostname],
              last_seen_utc: row[:last_seen_utc]
            }
          end

        enrich_with_status(devices)
      end

      def unmapped_devices
        devices = device_model.db[:devices]
          .left_join(:people, mac: :mac)
          .where(Sequel[:people][:mac] => nil)
          .select_all(:devices)
          .order(Sequel.desc(:last_seen_utc))
          .all
          .map do |row|
            {
              mac: row[:mac],
              ip: row[:ip],
              hostname: row[:hostname],
              last_seen_utc: row[:last_seen_utc]
            }
          end

        enrich_with_status(devices)
      end

      def split_by_presence(devices)
        cutoff = (Time.now.utc - (present_window_minutes * 60)).iso8601.gsub(/\+00:00\z/, "Z")

        present = devices.select { |d| d[:last_seen_utc] >= cutoff }
        absent = devices.select { |d| d[:last_seen_utc] < cutoff }

        [present, absent]
      end

      def dashboard_data
        mapped = mapped_devices
        mapped_present, mapped_absent = split_by_presence(mapped)

        {
          now: Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"),
          mapped_present: mapped_present,
          mapped_absent: mapped_absent.take(5),
          present_count: mapped_present.length,
          total_people: person_model.count,
          top_attendees: attendance_model.top_attendees(limit: 10)
        }
      end
    end
  end
end
