# frozen_string_literal: true

Sequel.migration do
  up do
    unless table_exists?(:settings)
      create_table(:settings) do
        String :key, primary_key: true
        String :value
      end
    end
  end

  down do
    drop_table?(:settings)
  end
end
