# frozen_string_literal: true

require "sinatra/base"
require "sinatra/json"
require "json"
require "time"
require "rack/auth/basic"

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

      def admin_protected!
        return if admin_authorized?

        headers["WWW-Authenticate"] = 'Basic realm="Admin"'
        halt 401, "Not authorized"
      end

      def admin_authorized?
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials == ["admin", "admin"]
      end
    end

    # Routes - Web Pages
    get "/" do
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

    get "/admin" do
      admin_protected!

      mapped = presence_model.mapped_devices
      unmapped = presence_model.unmapped_devices

      mapped_present, mapped_absent = presence_model.split_by_presence(mapped)
      unmapped_present, unmapped_past = presence_model.split_by_presence(unmapped)

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
      redirect "/", 302
    end

    # Routes - API
    get "/api/presence" do
      # Get devices from presence model (already includes status)
      mapped = presence_model.mapped_devices.map do |row|
        row.merge(mapped: true)
      end

      unmapped = presence_model.unmapped_devices.map do |row|
        row.merge(mapped: false, person: nil, device: nil)
      end

      json(mapped + unmapped)
    end

    get "/api/dashboard" do
      json(presence_model.dashboard_data)
    end

    get "/api/config" do
      json(
        present_window_minutes: present_window_minutes,
        ping_interval: settings.scanner.ping_interval
      )
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
