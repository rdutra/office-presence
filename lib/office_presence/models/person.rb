# frozen_string_literal: true

module OfficePresence
  module Models
    class Person
      attr_reader :db

      def initialize(db)
        @db = db
      end

      def all
        db[:people].all
      end

      def count
        db[:people].count
      end

      def find_by_mac(mac)
        db[:people].where(mac: mac).first
      end

      def find_by_device_id(device_id)
        return nil if device_id.nil? || device_id.empty?
        db[:people].where(device_id: device_id).first
      end

      def create_or_update(mac:, person:, device:, visible: true, device_id: nil)
        updates = { person: person, device: device, visible: visible }
        updates[:device_id] = device_id if device_id && !device_id.empty?

        attributes = {
          mac: mac,
          person: person,
          device: device,
          visible: visible
        }
        attributes[:device_id] = device_id if device_id && !device_id.empty?

        db[:people].insert_conflict(
          target: :mac,
          update: updates
        ).insert(attributes)
      end
      
      def toggle_visibility(mac:)
        person = find_by_mac(mac)
        return false unless person
        
        new_visibility = !person.fetch(:visible, true)
        db[:people].where(mac: mac).update(visible: new_visibility)
        new_visibility
      end
      
      def set_visibility(mac:, visible:)
        db[:people].where(mac: mac).update(visible: visible)
      end
    end
  end
end
