# frozen_string_literal: true

Sequel.migration do
  up do
    columns = self[:devices].columns
    unless columns.include?(:ping_failure_count)
      alter_table(:devices) do
        add_column :ping_failure_count, Integer, default: 0, null: false
      end
    end
  end

  down do
    columns = self[:devices].columns
    if columns.include?(:ping_failure_count)
      alter_table(:devices) do
        drop_column :ping_failure_count
      end
    end
  end
end
