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
      
      def find_by_device_id(device_id)
        return nil unless device_id && !device_id.empty?
        db[:devices].where(device_id: device_id).first
      end

      def find_by_ip(ip)
        db[:devices].where(ip: ip).first
      end

      def create_or_update(mac:, ip: nil, last_seen_utc: nil, hostname: nil, device_id: nil)
        last_seen_utc ||= Time.now.utc.iso8601.gsub(/\+00:00\z/, "Z")
        
        # First check if this device_id exists with a different MAC
        if device_id && !device_id.empty?
          existing_by_device_id = find_by_device_id(device_id)
          if existing_by_device_id && existing_by_device_id[:mac] != mac
            updates = { last_seen_utc: last_seen_utc }
            updates[:ip] = ip if ip && !ip.empty?
            updates[:hostname] = hostname if hostname && !hostname.empty?
            updates[:device_id] = device_id

            # If another record already uses this MAC (e.g., from ARP),
            # merge the data into that record and delete the duplicate
            if (existing_by_mac = find_by_mac(mac))
              db[:devices].where(mac: mac).update(updates)
              db[:devices].where(device_id: device_id).exclude(mac: mac).delete
            else
              # Safe to update the existing record to the new MAC
              updates[:mac] = mac
              db[:devices].where(device_id: device_id).update(updates)
            end
            return
          end
        end
        
        # Normal path: find by MAC
        existing = find_by_mac(mac)
        if existing
          updates = { last_seen_utc: last_seen_utc }
          updates[:ip] = ip if ip && !ip.empty?
          updates[:hostname] = hostname if hostname && !hostname.empty?
          updates[:device_id] = device_id if device_id && !device_id.empty?
          db[:devices].where(mac: mac).update(updates)
        else
          db[:devices].insert(
            mac: mac,
            ip: ip,
            last_seen_utc: last_seen_utc,
            hostname: hostname,
            device_id: device_id
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
