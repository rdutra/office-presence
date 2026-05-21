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

      def upsert(week_start:, week_end:, person:, person_mac:, days:)
        db[:weekly_winners].insert_conflict(
          target: :week_start,
          update: { week_end: week_end.to_s, person: person, person_mac: person_mac, days: days }
        ).insert(
          week_start: week_start.to_s,
          week_end: week_end.to_s,
          person: person,
          person_mac: person_mac,
          days: days
        )
      end

      def last_winner
        db[:weekly_winners].order(Sequel.desc(:week_start)).first
      end

      def counts_by_person_key
        current_person_expr = Sequel.function(:coalesce, Sequel[:people][:person], Sequel[:weekly_winners][:person])

        db[:weekly_winners]
          .left_join(:people, mac: :person_mac)
          .exclude(anonymous_name_condition)
          .group_and_count(current_person_expr.as(:person))
          .all
          .each_with_object({}) do |row, counts|
            counts[row[:person]] = row[:count]
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
