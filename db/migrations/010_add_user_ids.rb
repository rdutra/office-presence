# frozen_string_literal: true

Sequel.migration do
  up do
    if table_exists?(:people) && !self[:people].columns.include?(:user_id)
      alter_table(:people) { add_column :user_id, String }
    end

    if table_exists?(:weekly_winners) && !self[:weekly_winners].columns.include?(:user_id)
      alter_table(:weekly_winners) { add_column :user_id, String }
    end
  end

  down do
    if table_exists?(:weekly_winners) && self[:weekly_winners].columns.include?(:user_id)
      alter_table(:weekly_winners) { drop_column :user_id }
    end

    if table_exists?(:people) && self[:people].columns.include?(:user_id)
      alter_table(:people) { drop_column :user_id }
    end
  end
end
