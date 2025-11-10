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
      end

      db.create_table?(:people) do
        String :mac, primary_key: true
        String :person
        String :device
        TrueClass :visible, default: true
      end
      
      # Add visible column if it doesn't exist (for existing databases)
      unless db[:people].columns.include?(:visible)
        db.alter_table(:people) do
          add_column :visible, TrueClass, default: true
        end
        # Set existing records to visible by default
        db[:people].update(visible: true)
      end

      db.create_table?(:attendance) do
        primary_key :id
        String :mac, null: false
        String :date, null: false # YYYY-MM-DD format
        String :first_seen_utc
        String :last_seen_utc
        index [:mac, :date], unique: true
      end
    end
  end
end
