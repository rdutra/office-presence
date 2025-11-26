# frozen_string_literal: true

module OfficePresence
  module Models
    class Settings
      attr_reader :db

      def initialize(db)
        @db = db
      end

      def get(key, default = nil)
        record = db[:settings].where(key: key).first
        record ? record[:value] : default
      end

      def set(key, value)
        db[:settings].insert_conflict(:replace).insert(key: key, value: value.to_s)
      end

      def get_boolean(key, default = false)
        value = get(key)
        return default if value.nil?
        value == 'true'
      end

      def all
        db[:settings].all.each_with_object({}) do |row, hash|
          hash[row[:key]] = row[:value]
        end
      end
    end
  end
end
