# frozen_string_literal: true

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

      def upsert(week_start:, week_end:, person:, days:)
        db[:weekly_winners].insert_conflict(
          target: :week_start,
          update: { week_end: week_end.to_s, person: person, days: days }
        ).insert(
          week_start: week_start.to_s,
          week_end: week_end.to_s,
          person: person,
          days: days
        )
      end

      def last_winner
        db[:weekly_winners].order(Sequel.desc(:week_start)).first
      end

      def counts_by_person
        db[:weekly_winners]
          .group_and_count(:person)
          .all
          .each_with_object({}) do |row, counts|
            counts[row[:person]] = row[:count]
          end
      end
    end
  end
end
