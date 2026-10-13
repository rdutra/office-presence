# frozen_string_literal: true

require_relative "person"

module OfficePresence
  module Models
    class WeeklyWinner
      attr_reader :db

      def initialize(db)
        @db = db
      end

      def find_by_week_start(week_start)
        db[:weekly_winners].where(week_start: week_start.to_s).first
      end

      def upsert(week_start:, week_end:, person:, person_mac:, days:, user_id: nil)
        updates = { week_end: week_end.to_s, person: person, person_mac: person_mac, days: days }
        updates[:user_id] = user_id if user_id && !user_id.empty?

        db[:weekly_winners].insert_conflict(
          target: :week_start,
          update: updates
        ).insert(
          week_start: week_start.to_s,
          week_end: week_end.to_s,
          person: person,
          person_mac: person_mac,
          user_id: user_id,
          days: days
        )
      end

      def last_winner
        db[:weekly_winners].order(Sequel.desc(:week_start)).first
      end

      def counts_by_person_key
        historical_user_id = Sequel.lit(<<~SQL)
          (SELECT person_mac_history.user_id
           FROM person_mac_history
           WHERE person_mac_history.mac = weekly_winners.person_mac
             AND (person_mac_history.first_seen_at IS NULL OR date(weekly_winners.week_end) >= date(person_mac_history.first_seen_at))
             AND (person_mac_history.last_seen_at IS NULL OR date(weekly_winners.week_start) <= date(person_mac_history.last_seen_at))
           ORDER BY person_mac_history.first_seen_at DESC
           LIMIT 1)
        SQL
        current_person_key_expr = Sequel.function(
          :coalesce,
          Sequel[:weekly_winners][:user_id],
          historical_user_id,
          Sequel[:people][:user_id],
          Sequel[:people][:mac],
          Sequel[:weekly_winners][:person_mac]
        )

        db[:weekly_winners]
          .left_join(:people, mac: :person_mac)
          .exclude(anonymous_name_condition)
          .group_and_count(current_person_key_expr.as(:person_key))
          .all
          .each_with_object({}) do |row, counts|
            counts[row[:person_key]] = row[:count]
          end
      end

      private

      def non_anonymous_dataset
        db[:weekly_winners].exclude(anonymous_name_condition)
      end

      def anonymous_name_condition
        Person.anonymous_name_condition(Sequel[:weekly_winners][:person])
      end
    end
  end
end
