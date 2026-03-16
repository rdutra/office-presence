# frozen_string_literal: true

Sequel.migration do
  up do
    if table_exists?(:people)
      people = self[:people]
      if people.columns.include?(:person) && people.columns.include?(:device)
        people
          .where(Sequel.like(:person, "Anonymous %"))
          .where(device: "Auto-detected device")
          .where(Sequel.|({ device_id: nil }, { device_id: "" }))
          .delete
      end
    end
  end

  down do
    # Irreversible cleanup: intentionally left blank.
  end
end
