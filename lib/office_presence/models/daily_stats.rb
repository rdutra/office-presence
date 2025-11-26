# frozen_string_literal: true

module OfficePresence
  module Models
    class DailyStats
      attr_reader :db

      def initialize(db)
        @db = db
      end

      # Get the maximum number of concurrent people present across all time
      def all_time_max_concurrent
        # Get all unique dates from attendance records
        all_dates = db[:attendance]
          .select(:date)
          .distinct
          .map { |record| record[:date] }

        return 0 if all_dates.empty?

        # Calculate max concurrent for each date and find the maximum
        max_across_all_days = all_dates.map do |date|
          calculate_max_concurrent_for_date(date)
        end.max || 0

        max_across_all_days
      rescue StandardError => e
        puts "Error calculating all-time max concurrent: #{e.message}"
        0
      end

      # Get the maximum number of concurrent people present today
      def today_max_concurrent
        today = Time.now.utc.to_date.to_s # YYYY-MM-DD format
        calculate_max_concurrent_for_date(today)
      rescue StandardError => e
        puts "Error calculating daily max concurrent: #{e.message}"
        0
      end

      private

      # Calculate max concurrent for a specific date
      def calculate_max_concurrent_for_date(date)
        # Get all attendance records for the date
        attendance_records = db[:attendance]
          .where(date: date)
          .select(:mac, :first_seen_utc, :last_seen_utc)
          .all

        return 0 if attendance_records.empty?

        # Get only visible people
        visible_macs = db[:people]
          .where(visible: true)
          .select(:mac)
          .map { |p| p[:mac] }

        # Filter to only visible people
        attendance_records = attendance_records.select { |a| visible_macs.include?(a[:mac]) }

        return 0 if attendance_records.empty?

        # Convert time strings to Time objects and create intervals
        intervals = attendance_records.map do |record|
          {
            start: Time.parse(record[:first_seen_utc]),
            finish: Time.parse(record[:last_seen_utc])
          }
        end

        # Find all unique time points (starts and ends)
        time_points = []
        intervals.each do |interval|
          time_points << { time: interval[:start], type: :start }
          time_points << { time: interval[:finish], type: :finish }
        end

        # Sort time points chronologically
        time_points.sort_by! { |tp| tp[:time] }

        # Sweep through time points counting concurrent presence
        current_count = 0
        max_count = 0

        time_points.each do |tp|
          if tp[:type] == :start
            current_count += 1
            max_count = [max_count, current_count].max
          else
            current_count -= 1
          end
        end

        max_count
      end
    end
  end
end
