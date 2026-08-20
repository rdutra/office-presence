Sequel.migration do
  up do
    alter_table(:people) do
      add_column :audio_filename, String
    end
  end

  down do
    alter_table(:people) do
      drop_column :audio_filename
    end
  end
end
