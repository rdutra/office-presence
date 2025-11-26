# frozen_string_literal: true

require "fileutils"
require "sequel"
require "sqlite3"

module OfficePresence
  module Database
    module_function

    def connection
      @connection ||= begin
        FileUtils.mkdir_p(DATA_DIR)
        db = Sequel.sqlite(DB_PATH)
        ensure_schema(db)
        db
      end
    end

    def ensure_schema(db)
      db.create_table?(:devices) do
        String :mac, primary_key: true
        String :ip
        String :last_seen_utc
        String :hostname
        String :device_id  # AirPlay device ID or Bluetooth address (persistent)
      end
      
      # Add new columns if they don't exist (for existing databases)
      unless db[:devices].columns.include?(:hostname)
        db.alter_table(:devices) do
          add_column :hostname, String
        end
      end
      
      unless db[:devices].columns.include?(:device_id)
        db.alter_table(:devices) do
          add_column :device_id, String
        end
      end

      db.create_table?(:people) do
        String :mac, primary_key: true
        String :person
        String :device
        TrueClass :visible, default: true
        String :device_id
      end
      
      # Add visible column if it doesn't exist (for existing databases)
      unless db[:people].columns.include?(:visible)
        db.alter_table(:people) do
          add_column :visible, TrueClass, default: true
        end
        # Set existing records to visible by default
        db[:people].update(visible: true)
      end
      
      unless db[:people].columns.include?(:device_id)
        db.alter_table(:people) do
          add_column :device_id, String
        end
      end
      
      # Backfill device_id for people when possible (no-op if already set)
      if db[:people].columns.include?(:device_id)
        unmapped = db[:people].where(device_id: nil).count
        if unmapped.positive?
          db[:people].where(device_id: nil).each do |person|
            device = db[:devices].where(mac: person[:mac]).first
            next unless device && device[:device_id]
            db[:people].where(mac: person[:mac]).update(device_id: device[:device_id])
          end
        end
      end

      db.create_table?(:attendance) do
        primary_key :id
        String :mac, null: false
        String :date, null: false # YYYY-MM-DD format
        String :first_seen_utc
        String :last_seen_utc
        index [:mac, :date], unique: true
        index :mac
      end

      db.create_table?(:settings) do
        String :key, primary_key: true
        String :value
      end

      # Initialize default settings if not exists
      if db.table_exists?(:settings)
        db[:settings].insert_conflict(:replace).insert(key: 'show_in_office_tile', value: 'true') unless db[:settings].where(key: 'show_in_office_tile').any?
        db[:settings].insert_conflict(:replace).insert(key: 'show_registered_users_tile', value: 'true') unless db[:settings].where(key: 'show_registered_users_tile').any?
        db[:settings].insert_conflict(:replace).insert(key: 'show_today_record_tile', value: 'true') unless db[:settings].where(key: 'show_today_record_tile').any?
        db[:settings].insert_conflict(:replace).insert(key: 'show_all_time_record_tile', value: 'true') unless db[:settings].where(key: 'show_all_time_record_tile').any?
      end

      # Add indexes for performance (idempotent)
      [:device_id, :last_seen_utc].each do |col|
        unless db.indexes(:devices).values.any? { |idx| idx[:columns] == [col] }
          db.alter_table(:devices) do
            add_index col
          end
        end
      end

      unless db.indexes(:attendance).values.any? { |idx| idx[:columns] == [:mac] }
        db.alter_table(:attendance) do
          add_index :mac
        end
      end
      
      if db[:people].columns.include?(:device_id)
        unless db.indexes(:people).values.any? { |idx| idx[:columns] == [:device_id] }
          db.alter_table(:people) do
            add_index :device_id
          end
        end
      end
    end
  end
end
