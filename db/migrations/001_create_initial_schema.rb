# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:devices) do
      String :mac, primary_key: true
      String :ip
      String :last_seen_utc
      String :hostname
      String :device_id
    end

    existing_device_columns = self[:devices].columns
    unless existing_device_columns.include?(:hostname)
      alter_table(:devices) do
        add_column(:hostname, String)
      end
    end
    unless existing_device_columns.include?(:device_id)
      alter_table(:devices) do
        add_column(:device_id, String)
      end
    end

    create_table?(:people) do
      String :mac, primary_key: true
      String :person
      String :device
      TrueClass :visible, default: true
      String :device_id
    end

    existing_people_columns = self[:people].columns
    unless existing_people_columns.include?(:visible)
      alter_table(:people) do
        add_column(:visible, TrueClass, default: true)
      end
    end
    unless existing_people_columns.include?(:device_id)
      alter_table(:people) do
        add_column(:device_id, String)
      end
    end
    self[:people].where(visible: nil).update(visible: true)

    create_table?(:attendance) do
      primary_key :id
      String :mac, null: false
      String :date, null: false
      String :first_seen_utc
      String :last_seen_utc
      index [:mac, :date], unique: true
    end

    device_indexes = indexes(:devices).values.map { |idx| idx[:columns] }
    unless device_indexes.include?([:device_id])
      alter_table(:devices) { add_index :device_id }
    end
    unless device_indexes.include?([:last_seen_utc])
      alter_table(:devices) { add_index :last_seen_utc }
    end

    people_indexes = indexes(:people).values.map { |idx| idx[:columns] }
    unless people_indexes.include?([:device_id])
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

  down do
    drop_table?(:attendance)
    drop_table?(:people)
    drop_table?(:devices)
  end
end
