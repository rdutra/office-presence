# frozen_string_literal: true

require "time"
require "date"

module OfficePresence
  module Models
    class Attendance
      attr_reader :db

      def initialize(db)
        @db = db
      end

      def all
        db[:attendance].all
      end

      def find_by_mac_and_date(mac:, date:)
        db[:attendance].where(mac: mac, date: date).first
      end

      def record(mac:, timestamp: nil, date: nil)
        timestamp ||= Time.now.utc.iso8601.gsub(/\+00:00\z/, "Z")
        date ||= Time.now.utc.strftime("%Y-%m-%d")
        
        db[:attendance].insert_conflict(
          target: [:mac, :date],
          update: { last_seen_utc: timestamp }
        ).insert(
          mac: mac,
          date: date,
          first_seen_utc: timestamp,
          last_seen_utc: timestamp
        )
      end

      def top_attendees(limit: 10)
        top_attendees_in_range(limit: limit)
      end

      def days_for_mac(mac)
        db[:attendance]
          .where(mac: mac)
          .select { count(distinct(:date)).as(:days) }
          .first[:days]
      end

      def week_bounds(reference_date = Date.today)
        date = to_date(reference_date)
        start_of_week = date - (date.cwday - 1)
        [start_of_week, start_of_week + 6]
      end

      def top_attendees_in_range(start_date: nil, end_date: nil, limit: 10)
        devices_for_attendance = db[:devices].select(:mac, :device_id).as(:devices_for_attendance)
        people_by_device = db[:people].as(:people_by_device)
        person_expr = Sequel.function(:coalesce, Sequel[:people][:person], Sequel[:people_by_device][:person])
        visible_expr = Sequel.function(:coalesce, Sequel[:people][:visible], Sequel[:people_by_device][:visible], true)

        dataset = db[:attendance]
          .left_join(:people, mac: :mac)
          .left_join(devices_for_attendance, Sequel[:attendance][:mac] => Sequel[:devices_for_attendance][:mac])
          .left_join(people_by_device, Sequel[:people_by_device][:device_id] => Sequel[:devices_for_attendance][:device_id])
          .where(
            Sequel.|(
              Sequel.~(Sequel[:people][:person] => nil),
              Sequel.~(Sequel[:people_by_device][:person] => nil)
            )
          )
          .where(visible_expr => true)

        if start_date
          dataset = dataset.where { Sequel[:attendance][:date] >= start_date.to_s }
        end
        if end_date
          dataset = dataset.where { Sequel[:attendance][:date] <= end_date.to_s }
        end

        dataset
          .select(
            person_expr.as(:person),
            Sequel.function(:count, Sequel.function(:distinct, Sequel[:attendance][:date])).as(:days)
          )
          .group(person_expr)
          .order(Sequel.desc(:days))
          .limit(limit)
          .all
          .map { |row| { person: row[:person], days: row[:days] } }
      end

      def top_attendees_for_week(reference_time: Time.now, limit: 10)
        start_date, end_date = week_bounds(to_date(reference_time))
        top_attendees_in_range(start_date: start_date, end_date: end_date, limit: limit)
      end

      def winner_for_week(reference_time: Time.now)
        top_attendees_for_week(reference_time: reference_time, limit: 1).first
      end

      def top_attendees_with_max_days(start_date: nil, end_date: nil)
        all_attendees = top_attendees_in_range(start_date: start_date, end_date: end_date, limit: 1000)
        return [] if all_attendees.empty?
        
        max_days = all_attendees.first[:days]
        all_attendees.select { |attendee| attendee[:days] == max_days }
      end

      private

      def to_date(value)
        return value if value.is_a?(Date)
        return value.to_date if value.respond_to?(:to_date)
        Date.parse(value.to_s)
      end
    end
  end
end
