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
        person_key_expr = Sequel.function(:coalesce, Sequel[:weekly_winners][:person_mac], Sequel[:weekly_winners][:person])

        non_anonymous_dataset
          .select(person_key_expr.as(:person_key), Sequel.function(:count, 1).as(:count))
          .group(person_key_expr)
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
