# frozen_string_literal: true

Sequel.migration do
  up do
    unless table_exists?(:devices)
      create_table(:devices) do
        String :mac, primary_key: true
        String :ip
        String :last_seen_utc
        String :hostname
        String :device_id
      end
    else
      existing_columns = self[:devices].columns
      unless existing_columns.include?(:hostname)
        alter_table(:devices) do
          add_column(:hostname, String)
        end
      end
      unless existing_columns.include?(:device_id)
        alter_table(:devices) do
          add_column(:device_id, String)
        end
      end
    end

    unless table_exists?(:people)
      create_table(:people) do
        String :mac, primary_key: true
        String :person
        String :device
        TrueClass :visible, default: true
        String :device_id
      end
    else
      existing_columns = self[:people].columns
      unless existing_columns.include?(:visible)
        alter_table(:people) do
          add_column(:visible, TrueClass, default: true)
        end
      end
      unless existing_columns.include?(:device_id)
        alter_table(:people) do
          add_column(:device_id, String)
        end
      end
      self[:people].where(visible: nil).update(visible: true)
    end

    unless table_exists?(:attendance)
      create_table(:attendance) do
        primary_key :id
        String :mac, null: false
        String :date, null: false
        String :first_seen_utc
        String :last_seen_utc
        index [:mac, :date], unique: true
      end
    end

    if table_exists?(:devices)
      cols = indexes(:devices).values.map { |idx| idx[:columns] }
      unless cols.include?([:device_id])
        alter_table(:devices) { add_index :device_id }
      end
      unless cols.include?([:last_seen_utc])
        alter_table(:devices) { add_index :last_seen_utc }
      end
    end

    if table_exists?(:attendance)
      cols = indexes(:attendance).values.map { |idx| idx[:columns] }
      unless cols.include?([:mac])
        alter_table(:attendance) { add_index :mac }
      end
    end

    if table_exists?(:people)
      cols = indexes(:people).values.map { |idx| idx[:columns] }
      unless cols.include?([:device_id])
        alter_table(:people) { add_index :device_id }
      end

      if self[:people].columns.include?(:device_id)
        people = self[:people]
        people.where(device_id: nil).each do |person|
          device = self[:devices].where(mac: person[:mac]).first
          next unless device && device[:device_id]
          people.where(mac: person[:mac]).update(device_id: device[:device_id])
        end
      end
    end
  end

  down do
    drop_table?(:attendance)
    drop_table?(:people)
    drop_table?(:devices)
  end
end
