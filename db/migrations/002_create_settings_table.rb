# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:settings) do
      String :key, primary_key: true
      String :value
    end
  end

  down do
    drop_table?(:settings)
  end
end
