# frozen_string_literal: true

require "time"

module OfficePresence
  module Models
    class Device
      attr_reader :db

      def initialize(db)
        @db = db
      end

      def all
        db[:devices].all
      end

      def find_by_mac(mac)
        db[:devices].where(mac: mac).first
      end

      def find_by_ip(ip)
        db[:devices].where(ip: ip).first
      end

      def create_or_update(mac:, ip: nil, hostname: nil, last_seen_utc: nil)
        last_seen_utc ||= Time.now.utc.iso8601.gsub(/\+00:00\z/, "Z")
        
        existing = find_by_mac(mac)
        if existing
          updates = { last_seen_utc: last_seen_utc }
          updates[:ip] = ip if ip && !ip.empty?
          updates[:hostname] = hostname if hostname && !hostname.empty?
          db[:devices].where(mac: mac).update(updates)
        else
          db[:devices].insert(
            mac: mac,
            ip: ip,
            hostname: hostname,
            last_seen_utc: last_seen_utc
          )
        end
      end

      def present(window_minutes)
        cutoff = (Time.now.utc - (window_minutes * 60)).iso8601.gsub(/\+00:00\z/, "Z")
        db[:devices].where(Sequel.lit("last_seen_utc >= ?", cutoff)).all
      end

      def absent(window_minutes)
        cutoff = (Time.now.utc - (window_minutes * 60)).iso8601.gsub(/\+00:00\z/, "Z")
        db[:devices].where(Sequel.lit("last_seen_utc < ?", cutoff)).all
      end
    end
  end
end
