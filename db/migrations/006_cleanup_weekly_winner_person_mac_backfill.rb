# frozen_string_literal: true

Sequel.migration do
  up do
    if table_exists?(:weekly_winners)
      weekly_winners = self[:weekly_winners]
      if weekly_winners.columns.include?(:person_mac)
        # Historic week with known low-confidence identity mapping.
        weekly_winners.where(week_start: "2025-11-24").update(person_mac: nil)

        if table_exists?(:people)
          invalid_macs = self[:people]
            .where(Sequel.|({ device_id: nil }, { device_id: "" }))
            .select_map(:mac)

          weekly_winners.where(person_mac: invalid_macs).update(person_mac: nil) unless invalid_macs.empty?
        end
      end
    end
  end

  down do
    # Irreversible cleanup: intentionally left blank.
  end
end
