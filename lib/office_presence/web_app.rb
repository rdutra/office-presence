# frozen_string_literal: true

require "sinatra/base"
require "sinatra/json"
require "json"
require "time"

require_relative "../office_presence"
require_relative "scanner"
require_relative "models/presence"
require_relative "models/person"

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

      def presence_model
        @presence_model ||= Models::Presence.new(db, present_window_minutes: present_window_minutes)
      end

      def person_model
        @person_model ||= Models::Person.new(db)
      end

      def present_window_minutes
        settings.scanner.present_window_minutes
      end

      def client_ip
        request.ip
      end

      def parse_json_body
        request.body.rewind
        JSON.parse(request.body.read)
      end

      def parse_timestamp(value)
        return nil if value.nil? || value.empty?
        Time.parse(value)
      rescue ArgumentError
        nil
      end

      def calculate_device_status(last_seen_utc)
        return 'calculating' unless last_seen_utc

        last_seen = parse_timestamp(last_seen_utc)
        return 'calculating' unless last_seen

        diff_seconds = Time.now.utc - last_seen

        if diff_seconds < 20 # Active: responded to recent ping (2x ping interval buffer)
          'active'
        elsif diff_seconds < (10 * 60) # Inactive: not responding but still within presence window
          'inactive'
        else
          'inactive'
        end
      end

      def enrich_with_status(devices)
        devices.map do |device|
          device.merge(status: calculate_device_status(device[:last_seen_utc]))
        end
      end
    end

    # Routes - Web Pages
    get "/" do
      mapped = presence_model.mapped_devices
      unmapped = presence_model.unmapped_devices

      mapped_present, mapped_absent = presence_model.split_by_presence(mapped)
      unmapped_present, unmapped_past = presence_model.split_by_presence(unmapped)

      # Enrich with server-calculated status
      mapped_present = enrich_with_status(mapped_present)
      mapped_absent = enrich_with_status(mapped_absent)

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
      data = presence_model.dashboard_data

      erb :dashboard, locals: {
        now: Time.now,
        mapped_present: data[:mapped_present],
        mapped_absent: data[:mapped_absent],
        present_count: data[:present_count],
        total_people: data[:total_people],
        top_attendees: data[:top_attendees]
      }
    end

    # Routes - API
    get "/api/presence" do
      # Get devices from presence model
      mapped = presence_model.mapped_devices.map do |row|
        {
          mapped: true,
          person: row[:person],
          device: row[:device],
          mac: row[:mac],
          ip: row[:ip],
          hostname: row[:hostname],
          last_seen_utc: row[:last_seen_utc],
          status: calculate_device_status(row[:last_seen_utc])
        }
      end

      unmapped = presence_model.unmapped_devices.map do |row|
        {
          mapped: false,
          person: nil,
          device: nil,
          mac: row[:mac],
          ip: row[:ip],
          hostname: row[:hostname],
          last_seen_utc: row[:last_seen_utc],
          status: calculate_device_status(row[:last_seen_utc])
        }
      end

      json(mapped + unmapped)
    end

    get "/api/dashboard" do
      json(presence_model.dashboard_data)
    end

    get "/api/my-device" do
      ip = client_ip
      device = db[:devices].where(ip: ip).first

      unless device
        return json(
          ip: ip,
          mac: nil,
          registered: false,
          error: "No device found with your IP address (#{ip}). Make sure you're connected to the network and have been scanned."
        )
      end

      person = db[:people].where(mac: device[:mac]).first

      json(
        ip: ip,
        mac: device[:mac],
        registered: !person.nil?,
        person: person&.[](:person),
        device: person&.[](:device),
        visible: person&.[](:visible) != false
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

      existing = person_model.find_by_mac(device[:mac])
      if existing && existing[:person] != person_name
        halt 409, json(error: "This device is already registered to #{existing[:person]}")
      end

      visible = data["visible"] != false

      person_model.create_or_update(
        mac: device[:mac],
        person: person_name,
        device: device_name || "",
        visible: visible
      )

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
    
    post "/api/toggle-visibility" do
      ip = client_ip
      device = db[:devices].where(ip: ip).first
      
      halt 404, json(error: "No device found with your IP address") unless device
      
      person = person_model.find_by_mac(device[:mac])
      halt 404, json(error: "Device is not registered") unless person
      
      new_visibility = person_model.toggle_visibility(mac: device[:mac])
      
      json(
        success: true,
        visible: new_visibility,
        message: new_visibility ? "You are now visible on the list" : "You are now hidden from the list"
      )
    rescue StandardError => e
      halt 500, json(error: "Failed to toggle visibility: #{e.message}")
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
