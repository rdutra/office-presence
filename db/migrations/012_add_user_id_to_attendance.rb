# frozen_string_literal: true

Sequel.migration do
  up do
    unless self[:attendance].columns.include?(:user_id)
      alter_table(:attendance) { add_column :user_id, String }
      alter_table(:attendance) { add_index :user_id }
    end

    # Backfill only unambiguous MAC ownership for the attendance date. A MAC
    # reused by multiple users is left unresolved for manual review.
    if table_exists?(:person_mac_history)
      self[:attendance].where(user_id: nil).each do |row|
        candidates = self[:person_mac_history].where(mac: row[:mac]).all.select do |history|
          first_ok = history[:first_seen_at].nil? || history[:first_seen_at][0, 10] <= row[:date]
          last_ok = history[:last_seen_at].nil? || history[:last_seen_at][0, 10] >= row[:date]
          first_ok && last_ok
        end.map { |history| history[:user_id] }.uniq
        candidates = [self[:people].where(mac: row[:mac]).get(:user_id)].compact.uniq if candidates.empty? && table_exists?(:people) && self[:people].columns.include?(:user_id)
        self[:attendance].where(id: row[:id]).update(user_id: candidates.first) if candidates.one?
      end
    end
  end

  down do
    if table_exists?(:attendance) && self[:attendance].columns.include?(:user_id)
      alter_table(:attendance) do
        drop_index :user_id
        drop_column :user_id
      end
    end
  end
end
