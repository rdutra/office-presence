# frozen_string_literal: true

require "sinatra/base"
require "sinatra/json"
require "json"
require "time"

require_relative "../office_presence"
require_relative "scanner"

module OfficePresence
  class WebApp < Sinatra::Base
    # Configuration
    set :root, File.expand_path("../..", __dir__)
    set :views, proc { File.join(root, "views") }
    set :public_folder, proc { File.join(root, "public") }
    enable :static
    set :show_exceptions, false

    configure do
      set :scanner, Scanner.new
      settings.scanner.start
    end

    # Helpers
    helpers do
      def db
        settings.scanner.db
      end

      def present_window_minutes
        settings.scanner.present_window_minutes
      end

      def present_cutoff
        Time.now.utc - (present_window_minutes * 60)
      end

      def known_macs
        @known_macs ||= db[:people].select_map(:mac)
      end

      def parse_timestamp(value)
        return nil if value.nil? || value.empty?
        Time.parse(value)
      rescue ArgumentError
        nil
      end

      def split_presence(rows)
        cutoff = present_cutoff
        rows.partition do |row|
          ts = parse_timestamp(row[:last_seen_utc])
          ts && ts >= cutoff
        end
      end

      def mapped_dataset
        db[:people].left_join(:devices, mac: :mac)
      end

      def unmapped_dataset
        dataset = db[:devices]
        dataset = dataset.exclude(mac: known_macs) unless known_macs.empty?
        dataset
      end

      def device_columns
        [
          Sequel[:people][:person],
          Sequel[:people][:device],
          Sequel[:people][:mac],
          Sequel[:devices][:ip],
          Sequel[:devices][:hostname],
          Sequel[:devices][:last_seen_utc]
        ]
      end

      def fetch_mapped_devices
        mapped_dataset
          .select(*device_columns)
          .order(Sequel[:people][:person].asc)
          .all
      end

      def fetch_unmapped_devices
        unmapped_dataset
          .order(Sequel[:devices][:last_seen_utc].desc)
          .all
      end

      def client_ip
        request.ip
      end

      def parse_json_body
        request.body.rewind
        JSON.parse(request.body.read)
      end

      def calculate_top_attendees
        # Count unique days per person from attendance table
        attendance_counts = db[:attendance]
          .join(:people, mac: :mac)
          .select(
            Sequel[:people][:person],
            Sequel.function(:count, Sequel.function(:distinct, Sequel[:attendance][:date])).as(:days)
          )
          .group(Sequel[:people][:person])
          .order(Sequel.desc(:days))
          .limit(10)
          .all
        
        attendance_counts.map do |row|
          { person: row[:person], days: row[:days] }
        end
      end

      def write_to_csv(mac, person, device)
        require "csv"
        csv_path = File.join(settings.root, "people.csv")
        
        # Read existing entries
        existing_rows = []
        if File.exist?(csv_path)
          existing_rows = CSV.read(csv_path, headers: true)
        end

        # Update or add the new entry
        found = false
        existing_rows.each do |row|
          if row["mac_address"]&.downcase&.gsub(/[:-]/, "") == mac.downcase.gsub(/[:-]/, "")
            row["person"] = person
            row["device"] = device
            found = true
            break
          end
        end

        unless found
          existing_rows << { "mac_address" => mac, "person" => person, "device" => device }
        end

        # Write back to CSV
        CSV.open(csv_path, "w") do |csv|
          csv << ["mac_address", "person", "device"]
          existing_rows.each do |row|
            csv << [row["mac_address"], row["person"], row["device"]]
          end
        end
      end
    end

    # Routes - Web Pages
    get "/" do
      mapped_rows = fetch_mapped_devices
      unmapped_rows = fetch_unmapped_devices

      mapped_present, mapped_absent = split_presence(mapped_rows)
      unmapped_present, unmapped_past = split_presence(unmapped_rows)

      erb :index, locals: {
        now: Time.now,
        mapped_present: mapped_present,
        mapped_absent: mapped_absent,
        unmapped_present: unmapped_present,
        unmapped_past: unmapped_past,
        present_window_minutes: present_window_minutes
      }
    end

    get "/dashboard" do
      mapped_rows = fetch_mapped_devices
      mapped_present, mapped_absent = split_presence(mapped_rows)
      
      # Calculate attendance stats
      top_attendees = calculate_top_attendees

      erb :dashboard, locals: {
        now: Time.now,
        mapped_present: mapped_present,
        mapped_absent: mapped_absent,
        present_count: mapped_present.length,
        total_people: db[:people].count,
        top_attendees: top_attendees
      }
    end

    # Routes - API
    get "/api/presence" do
      mapped = fetch_mapped_devices.map do |row|
        {
          mapped: true,
          person: row[:person],
          device: row[:device],
          mac: row[:mac],
          ip: row[:ip],
          hostname: row[:hostname],
          last_seen_utc: row[:last_seen_utc]
        }
      end

      unmapped = fetch_unmapped_devices.map do |row|
        {
          mapped: false,
          person: nil,
          device: nil,
          mac: row[:mac],
          ip: row[:ip],
          hostname: row[:hostname],
          last_seen_utc: row[:last_seen_utc]
        }
      end

      json(mapped + unmapped)
    end

    get "/api/dashboard" do
      mapped_rows = fetch_mapped_devices
      mapped_present, mapped_absent = split_presence(mapped_rows)
      top_attendees = calculate_top_attendees

      json(
        now: Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"),
        mapped_present: mapped_present,
        mapped_absent: mapped_absent.take(5),
        present_count: mapped_present.length,
        total_people: db[:people].count,
        top_attendees: top_attendees
      )
    end

    get "/api/my-device" do
      ip = client_ip
      device = db[:devices].where(ip: ip).first

      unless device
        return json(
          ip: ip,
          mac: nil,
          hostname: nil,
          registered: false,
          error: "No device found with your IP address (#{ip}). Make sure you're connected to the network and have been scanned."
        )
      end

      person = db[:people].where(mac: device[:mac]).first

      json(
        ip: ip,
        mac: device[:mac],
        hostname: device[:hostname],
        registered: !person.nil?,
        person: person&.[](:person),
        device: person&.[](:device)
      )
    end

    post "/api/register" do
      data = parse_json_body
      person_name = data["person"]&.strip
      device_name = data["device"]&.strip

      halt 400, json(error: "Person name is required") if person_name.nil? || person_name.empty?

      ip = client_ip
      device = db[:devices].where(ip: ip).first
      
      halt 404, json(error: "No device found with your IP address (#{ip}). Make sure you're connected to the network and have been scanned.") unless device

      existing = db[:people].where(mac: device[:mac]).first
      if existing && existing[:person] != person_name
        halt 409, json(error: "This device is already registered to #{existing[:person]}")
      end

      # Write to database
      db[:people].insert_conflict(
        target: :mac,
        update: { person: person_name, device: device_name || "" }
      ).insert(
        mac: device[:mac],
        person: person_name,
        device: device_name || ""
      )

      # Write to people.csv
      write_to_csv(device[:mac], person_name, device_name)

      @known_macs = nil # Clear cache

      json(
        success: true,
        message: "Successfully registered!",
        mac: device[:mac],
        person: person_name,
        device: device_name
      )
    rescue StandardError => e
      halt 500, json(error: "Failed to register: #{e.message}")
    end

    # Error Handlers
    not_found do
      "Not found"
    end

    error do
      "Internal error"
    end
  end
end
