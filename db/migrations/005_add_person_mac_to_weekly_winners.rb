# frozen_string_literal: true

Sequel.migration do
  up do
    if table_exists?(:weekly_winners)
      weekly_winners = self[:weekly_winners]

      unless weekly_winners.columns.include?(:person_mac)
        alter_table(:weekly_winners) do
          add_column :person_mac, String
        end
        weekly_winners = self[:weekly_winners]
      end

      people = table_exists?(:people) ? self[:people] : nil
      infer_person_mac_from_people = lambda do |person_name|
        next nil unless people
        next nil if person_name.nil? || person_name.strip.empty?

        matches = people
          .where(person: person_name)
          .exclude(device_id: nil)
          .exclude(device_id: "")
          .select(:mac)
          .limit(2)
          .all
        next nil unless matches.one?

        matches.first[:mac]
      end

      weekly_winners.where(person_mac: nil).exclude(person: nil).all.each do |winner|
        person_mac = infer_person_mac_from_people.call(winner[:person])
        next unless person_mac

        weekly_winners.where(id: winner[:id]).update(person_mac: person_mac)
      end

      winner_indexes = indexes(:weekly_winners).values.map { |index| index[:columns] }
      unless winner_indexes.include?([:person_mac])
        alter_table(:weekly_winners) do
          add_index :person_mac
        end
      end
    end
  end

  down do
    if table_exists?(:weekly_winners) && self[:weekly_winners].columns.include?(:person_mac)
      winner_indexes = indexes(:weekly_winners).values.map { |index| index[:columns] }
      if winner_indexes.include?([:person_mac])
        alter_table(:weekly_winners) do
          drop_index :person_mac
        end
      end

      alter_table(:weekly_winners) do
        drop_column :person_mac
      end
    end
  end

end
