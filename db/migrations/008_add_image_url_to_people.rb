# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:people) do
      add_column :image_url, String
    end
  end
end
