# frozen_string_literal: true

require "sinatra/base"
require "sinatra/json"
require "time"

require_relative "../office_presence"
require_relative "scanner"

module OfficePresence
  class WebApp < Sinatra::Base
    set :root, File.expand_path("../..", __dir__)
    set :views, File.expand_path("../../views", __dir__)
    set :show_exceptions, false

    configure do
      set :scanner, Scanner.new
      settings.scanner.start
    end

    helpers do
      def db
        settings.scanner.db
      end

      def present_window_minutes
        settings.scanner.present_window_minutes
      end

      def present_cutoff
        Time.now.utc - present_window_minutes * 60
      end

      def known_macs
        @known_macs ||= db[:people].select_map(:mac)
      end

      def split_presence(rows)
        present = []
        past = []
        cutoff = present_cutoff
        rows.each do |row|
          ts = parse_timestamp(row[:last_seen_utc])
          (ts && ts >= cutoff ? present : past) << row
        end
        [present, past]
      end

      def parse_timestamp(value)
        return nil if value.nil? || value.empty?
        Time.parse(value)
      rescue ArgumentError
        nil
      end

      def mapped_dataset
        db[:people].left_join(:devices, mac: :mac)
      end

      def unmapped_dataset
        dataset = db[:devices]
        dataset = dataset.exclude(mac: known_macs) unless known_macs.empty?
        dataset
      end
    end

    get "/" do
      now = Time.now
      mapped_rows = mapped_dataset
                    .select(Sequel[:people][:person], Sequel[:people][:device], Sequel[:people][:mac],
                            Sequel[:devices][:ip], Sequel[:devices][:hostname], Sequel[:devices][:last_seen_utc])
                    .order(Sequel[:people][:person].asc)
                    .all

      unmapped_rows = unmapped_dataset
                      .order(Sequel[:devices][:last_seen_utc].desc)
                      .all

      mapped_present, mapped_absent = split_presence(mapped_rows)
      unmapped_present, unmapped_past = split_presence(unmapped_rows)

      erb :index, locals: {
        now: now,
        mapped_present: mapped_present,
        mapped_absent: mapped_absent,
        unmapped_present: unmapped_present,
        unmapped_past: unmapped_past,
        present_window_minutes: present_window_minutes
      }
    end

    get "/api/presence" do
      rows = []

      mapped_dataset
        .select(Sequel[:people][:person], Sequel[:people][:device], Sequel[:people][:mac],
                Sequel[:devices][:ip], Sequel[:devices][:hostname], Sequel[:devices][:last_seen_utc])
        .all.each do |row|
          rows << {
            mapped: true,
            person: row[:person],
            device: row[:device],
            mac: row[:mac],
            ip: row[:ip],
            hostname: row[:hostname],
            last_seen_utc: row[:last_seen_utc]
          }
        end

      unmapped_dataset.all.each do |row|
        rows << {
          mapped: false,
          person: nil,
          device: nil,
          mac: row[:mac],
          ip: row[:ip],
          hostname: row[:hostname],
          last_seen_utc: row[:last_seen_utc]
        }
      end

      json rows
    end

    not_found do
      "Not found"
    end

    error do
      "Internal error"
    end
  end
end
