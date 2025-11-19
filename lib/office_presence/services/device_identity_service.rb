# frozen_string_literal: true

module OfficePresence
  module Services
    class DeviceIdentityService
      def initialize(db)
        @db = db
      end

      def migrate_identity(existing_record:, new_mac:, ip:, hostname:, last_seen_utc:)
        old_mac = existing_record[:mac]
        return if old_mac == new_mac || new_mac.nil?

        updates = { mac: new_mac, last_seen_utc: last_seen_utc }
        updates[:ip] = ip if ip && !ip.empty?
        updates[:hostname] = hostname if hostname && !hostname.empty?
        updates[:device_id] = existing_record[:device_id] if existing_record[:device_id]

        @db.transaction do
          merge_attendance_records(from_mac: new_mac, to_mac: old_mac)

          @db[:devices].where(mac: new_mac).delete
          @db[:people].where(mac: new_mac).delete

          @db[:devices].where(mac: old_mac).update(updates)
          @db[:people].where(mac: old_mac).update(mac: new_mac)
          @db[:attendance].where(mac: old_mac).update(mac: new_mac)
        end
      end

      private

      def merge_attendance_records(from_mac:, to_mac:)
        return if from_mac.nil? || to_mac.nil? || from_mac == to_mac

        attendance = @db[:attendance]
        attendance.where(mac: from_mac).each do |row|
          existing = attendance.where(mac: to_mac, date: row[:date]).first
          if existing
            first_seen = [existing[:first_seen_utc], row[:first_seen_utc]].compact.min
            last_seen = [existing[:last_seen_utc], row[:last_seen_utc]].compact.max
            attendance.where(id: existing[:id]).update(
              first_seen_utc: first_seen,
              last_seen_utc: last_seen
            )
            attendance.where(id: row[:id]).delete
          else
            attendance.where(id: row[:id]).update(mac: to_mac)
          end
        end
      end
    end
  end
end
