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
        
        existing = find_by_mac_and_date(mac: mac, date: date)
        if existing
          db[:attendance].where(mac: mac, date: date).update(last_seen_utc: timestamp)
        else
          db[:attendance].insert(
            mac: mac,
            date: date,
            first_seen_utc: timestamp,
            last_seen_utc: timestamp
          )
        end
      end

      def top_attendees(limit: 10)
        db[:attendance]
          .join(:people, mac: :mac)
          .select(
            Sequel[:people][:person],
            Sequel.function(:count, Sequel.function(:distinct, Sequel[:attendance][:date])).as(:days)
          )
          .group(Sequel[:people][:person])
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
