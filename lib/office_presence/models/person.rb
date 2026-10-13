# frozen_string_literal: true

require "securerandom"

module OfficePresence
  module Models
    class Person
      ANONYMOUS_NAME_PATTERN = /\AAnonymous(?:\s|$)/.freeze

      attr_reader :db

      def initialize(db)
        @db = db
      end

      def self.anonymous_name?(name)
        name.to_s.match?(ANONYMOUS_NAME_PATTERN)
      end

      def self.anonymous_name_condition(column)
        Sequel.|(
          Sequel.like(column, "Anonymous"),
          Sequel.like(column, "Anonymous %")
        )
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

      def find_by_user_id(user_id)
        return nil if user_id.nil? || user_id.empty?
        db[:people].where(user_id: user_id).first
      end

      def create_or_update(mac:, person:, device:, visible: true, device_id: nil, user_id: nil, image_url: nil, audio_filename: nil)
        existing = find_by_mac(mac)
        requested_user_id = user_id unless user_id.to_s.empty?
        stable_user_id = requested_user_id || existing&.[](:user_id) || user_id_for_device(device_id) || SecureRandom.uuid

        updates = { person: person, device: device, visible: visible }
        updates[:device_id] = device_id if device_id && !device_id.empty?
        updates[:user_id] = stable_user_id
        updates[:image_url] = image_url if image_url && !image_url.empty?
        updates[:audio_filename] = audio_filename if audio_filename && !audio_filename.empty?

        attributes = {
          mac: mac,
          person: person,
          device: device,
          visible: visible
        }
        attributes[:device_id] = device_id if device_id && !device_id.empty?
        attributes[:user_id] = stable_user_id
        attributes[:image_url] = image_url if image_url && !image_url.empty?
        attributes[:audio_filename] = audio_filename if audio_filename && !audio_filename.empty?

        db.transaction do
          db[:people].insert_conflict(
            target: :mac,
            update: updates
          ).insert(attributes)
          record_mac_history(user_id: stable_user_id, mac: mac, seen_at: Time.now.utc.iso8601, source: "registration")
          if db.table_exists?(:attendance) && db[:attendance].columns.include?(:user_id)
            db[:attendance].where(mac: mac, user_id: nil).update(user_id: stable_user_id)
          end
        end
      end

      private

      def user_id_for_device(device_id)
        return nil if device_id.nil? || device_id.empty?

        user_ids = db[:people].where(device_id: device_id).exclude(user_id: nil).select_map(:user_id).uniq
        raise ArgumentError, "device_id maps to conflicting user IDs: #{device_id}" if user_ids.length > 1

        user_ids.first
      end

      def record_mac_history(user_id:, mac:, seen_at:, source:)
        return unless db.table_exists?(:person_mac_history)

        db[:person_mac_history].insert_conflict(
          target: [:user_id, :mac],
          update: { last_seen_at: seen_at, source: source }
        ).insert(
          user_id: user_id,
          mac: mac,
          first_seen_at: seen_at,
          last_seen_at: seen_at,
          source: source
        )
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
