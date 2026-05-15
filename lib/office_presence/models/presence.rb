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
        medal_counts = weekly_winner_model.counts_by_person_key

        # Filter "Earlier today" to only show people who were present today
        today_start = Time.now.utc.to_date.to_time.utc.iso8601.gsub(/\+00:00\z/, "Z")
        earlier_today = mapped_absent.select { |d| d[:last_seen_utc] >= today_start }

        decorated_present = decorate_with_medals(mapped_present, medal_counts)
        decorated_absent = decorate_with_medals(earlier_today, medal_counts)
        decorated_attendees = decorate_with_medals(
          attendance_model.top_attendees_for_week(reference_time: Time.now, limit: 10),
          medal_counts
        )

        current_person_expr = Sequel.function(:coalesce, Sequel[:people][:person], Sequel[:weekly_winners][:person])
        person_key_expr = Sequel.function(:coalesce, Sequel[:weekly_winners][:person_mac], Sequel[:weekly_winners][:person])

        aggregated_winners = weekly_winner_model.db[:weekly_winners]
          .left_join(:people, mac: :person_mac)
          .exclude(Person.anonymous_name_condition(Sequel[:weekly_winners][:person]))
          .group_and_count(person_key_expr.as(:person_key), current_person_expr.as(:person))
          .order(Sequel.desc(:count), current_person_expr)
          .all

        attendance_trend = attendance_model.daily_attendance_timeline(limit: 90)

        {
          now: Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"),
          mapped_present: decorated_present,
          mapped_absent: decorated_absent.take(8),
          present_count: decorated_present.length,
          total_people: person_model.count,
          top_attendees: decorated_attendees,
          daily_record: daily_stats_model.today_max_concurrent,
          all_time_record: daily_stats_model.all_time_max_concurrent,
          current_week_start: current_week_bounds.first.to_s,
          current_week_end: current_week_bounds.last.to_s,
          last_week_winner: last_week_winner_data,
          weekly_winner_counts: medal_counts,
          aggregated_winners: aggregated_winners,
          attendance_trend: attendance_trend
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
        existing = nil if anonymous_winner?(existing)
        winner = existing || store_last_week_winner(start_date, end_date)

        return nil unless winner

        {
          person: winner_display_name(winner),
          days: winner[:days],
          week_start: winner[:week_start],
          week_end: winner[:week_end]
        }
      end

      def store_last_week_winner(start_date, end_date)
        top_performers = attendance_model.top_attendees_with_max_days(start_date: start_date, end_date: end_date)
        return nil if top_performers.empty?

        # If there's a tie, pick the person with the fewest total wins
        winner = if top_performers.length > 1
          select_winner_with_fewest_wins(top_performers)
        else
          top_performers.first
        end

        weekly_winner_model.upsert(
          week_start: start_date,
          week_end: end_date,
          person: winner[:person],
          person_mac: winner[:person_key],
          days: winner[:days]
        )

        weekly_winner_model.find_by_week_start(start_date.to_s)
      end

      def select_winner_with_fewest_wins(candidates)
        win_counts = weekly_winner_model.counts_by_person_key

        # Sort candidates by their total wins (ascending), then by name for stability
        candidates.min_by do |candidate|
          wins = win_counts[candidate[:person_key]] || 0
          [wins, candidate[:person].to_s.downcase]
        end
      end

      def decorate_with_medals(entries, medal_counts)
        entries.map do |entry|
          wins = medal_counts[entry_person_key(entry)] || 0
          entry.reject { |key, _| key == :person_key }.merge(
            weekly_wins: wins,
            medal: medal_string_for(wins)
          )
        end
      end

      def entry_person_key(entry)
        entry[:person_key] || entry[:mac] || entry[:person]
      end

      def winner_display_name(winner)
        mac = winner[:person_mac]
        return winner[:person] unless mac

        person = person_model.find_by_mac(mac)
        person&.[](:person) || winner[:person]
      end

      def anonymous_winner?(winner)
        return false unless winner
        return true if Person.anonymous_name?(winner[:person])

        mac = winner[:person_mac]
        return false unless mac

        person = person_model.find_by_mac(mac)
        Person.anonymous_name?(person&.[](:person))
      end

      def medal_string_for(wins)
        return nil unless wins.to_i.positive?

        medal_emoji = "🏅"
        wins <= 5 ? medal_emoji * wins : "#{wins}x#{medal_emoji}"
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
