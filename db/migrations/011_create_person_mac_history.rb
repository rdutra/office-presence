# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:person_mac_history) do
      primary_key :id
      String :user_id, null: false
      String :mac, null: false
      String :first_seen_at
      String :last_seen_at
      String :source, null: false, default: "identity"
      index [:user_id, :mac], unique: true
      index :mac
    end

    # Preserve current mappings when IDs have already been backfilled.
    if table_exists?(:people) && self[:people].columns.include?(:user_id)
      self[:people].exclude(user_id: nil).exclude(user_id: "").each do |person|
        attendance = table_exists?(:attendance) ? self[:attendance].where(mac: person[:mac]) : nil
        first_seen = attendance&.min(:first_seen_utc)
        last_seen = attendance&.max(:last_seen_utc)
        last_seen ||= self[:devices].where(mac: person[:mac]).get(:last_seen_utc) if table_exists?(:devices)

        self[:person_mac_history].insert_conflict(
          target: [:user_id, :mac],
          update: { last_seen_at: last_seen, source: "migration_backfill" }
        ).insert(
          user_id: person[:user_id],
          mac: person[:mac],
          first_seen_at: first_seen,
          last_seen_at: last_seen,
          source: "migration_backfill"
        )
      end
    end

    if table_exists?(:weekly_winners) && self[:weekly_winners].columns.include?(:user_id) &&
        table_exists?(:people) && self[:people].columns.include?(:user_id)
      self[:weekly_winners].where(user_id: nil).exclude(person_mac: nil).each do |winner|
        person = self[:people].where(mac: winner[:person_mac]).first
        next unless person && !person[:user_id].to_s.empty?

        self[:weekly_winners].where(id: winner[:id]).update(user_id: person[:user_id])
      end
    end
  end

  down do
    drop_table?(:person_mac_history)
  end
end
