# frozen_string_literal: true

require "date"

require_relative "device"
require_relative "person"
require_relative "attendance"
require_relative "daily_stats"
require_relative "weekly_winner"

module OfficePresence
  module Models
    class Presence
      attr_reader :device_model, :person_model, :attendance_model, :daily_stats_model, :weekly_winner_model, :present_window_minutes, :ping_interval, :ping_failure_limit

      # Status thresholds (in seconds)
      ACTIVE_THRESHOLD = 20      # Fallback threshold if config missing

      def initialize(db, present_window_minutes: 5, ping_interval: 30, ping_failure_limit: 3)
        @device_model = Device.new(db)
        @person_model = Person.new(db)
        @attendance_model = Attendance.new(db)
        @daily_stats_model = DailyStats.new(db)
        @weekly_winner_model = WeeklyWinner.new(db)
        @present_window_minutes = present_window_minutes
        @ping_interval = ping_interval
        @ping_failure_limit = ping_failure_limit
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
        threshold_seconds = active_window_seconds

        if diff_seconds < threshold_seconds
          'active'
        else
          'inactive'
        end
      end

      # Enrich device records with calculated status
      def enrich_with_status(devices)
        devices.map do |device|
          failure_count = device[:ping_failure_count].to_i
          status = calculate_status(device[:last_seen_utc])
          status = 'inactive' if failure_count >= ping_failure_limit

          device.merge(
            status: status,
            ping_failure_count: failure_count
          )
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
              device_id: row[:device_id],
              last_seen_utc: row[:last_seen_utc],
              ping_failure_count: row[:ping_failure_count]
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
              device_id: row[:device_id],
              last_seen_utc: row[:last_seen_utc],
              ping_failure_count: row[:ping_failure_count]
            }
          end

        enrich_with_status(devices)
      end

      def split_by_presence(devices)
        cutoff = (Time.now.utc - (present_window_minutes * 60)).iso8601.gsub(/\+00:00\z/, "Z")

        present = devices.select do |device|
          last_seen = device[:last_seen_utc]
          next false unless last_seen

          last_seen >= cutoff && device[:ping_failure_count].to_i < ping_failure_limit
        end

        absent = devices - present

        [present, absent]
      end

      def dashboard_data
        mapped = mapped_devices
        mapped_present, mapped_absent = split_by_presence(mapped)

        # Filter "Earlier today" to only show people who were present today
        today_start = Time.now.utc.to_date.to_time.utc.iso8601.gsub(/\+00:00\z/, "Z")
        earlier_today = mapped_absent.select { |d| d[:last_seen_utc] >= today_start }

        {
          now: Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"),
          mapped_present: mapped_present,
          mapped_absent: earlier_today.take(8),
          present_count: mapped_present.length,
          total_people: person_model.count,
          top_attendees: attendance_model.top_attendees_for_week(reference_time: Time.now, limit: 10),
          daily_record: daily_stats_model.today_max_concurrent,
          all_time_record: daily_stats_model.all_time_max_concurrent,
          current_week_start: current_week_bounds.first.to_s,
          current_week_end: current_week_bounds.last.to_s,
          last_week_winner: last_week_winner_data
        }
      end

      private

      def current_week_bounds
        attendance_model.week_bounds(Date.today)
      end

      def last_week_bounds
        start_date, _ = current_week_bounds
        last_week_start = start_date - 7
        [last_week_start, last_week_start + 6]
      end

      def last_week_winner_data
        start_date, end_date = last_week_bounds
        existing = weekly_winner_model.find_by_week_start(start_date.to_s)
        winner = existing || store_last_week_winner(start_date, end_date)

        return nil unless winner

        {
          person: winner[:person],
          days: winner[:days],
          week_start: winner[:week_start],
          week_end: winner[:week_end]
        }
      end

      def store_last_week_winner(start_date, end_date)
        winner = attendance_model.top_attendees_in_range(start_date: start_date, end_date: end_date, limit: 1).first
        return nil unless winner

        weekly_winner_model.upsert(
          week_start: start_date,
          week_end: end_date,
          person: winner[:person],
          days: winner[:days]
        )

        weekly_winner_model.find_by_week_start(start_date.to_s)
      end

      def active_window_seconds
        # Keep the "active" visual state at least as long as our ping cadence,
        # so rows don't gray out before the backend has a chance to validate.
        candidate = ping_interval.to_i * 2
        candidate = ACTIVE_THRESHOLD if candidate <= 0
        [candidate, present_window_minutes * 60].min
      rescue
        ACTIVE_THRESHOLD
      end
    end
  end
end
