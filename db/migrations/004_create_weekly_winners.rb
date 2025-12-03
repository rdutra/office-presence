# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:weekly_winners) do
      primary_key :id
      String :week_start, null: false
      String :week_end, null: false
      String :person, null: false
      Integer :days, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :week_start, unique: true
    end
  end

  down do
    drop_table?(:weekly_winners)
  end
end
