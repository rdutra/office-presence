# frozen_string_literal: true

require "time"

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
        devices_for_attendance = db[:devices].select(:mac, :device_id).as(:devices_for_attendance)
        people_by_device = db[:people].as(:people_by_device)
        person_expr = Sequel.function(:coalesce, Sequel[:people][:person], Sequel[:people_by_device][:person])
        visible_expr = Sequel.function(:coalesce, Sequel[:people][:visible], Sequel[:people_by_device][:visible], true)

        db[:attendance]
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

      def days_for_mac(mac)
        db[:attendance]
          .where(mac: mac)
          .select { count(distinct(:date)).as(:days) }
          .first[:days]
      end
    end
  end
end
