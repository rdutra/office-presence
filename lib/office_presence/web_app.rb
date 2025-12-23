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
require_relative "models/settings"

module OfficePresence
  class WebApp < Sinatra::Base
    DASHBOARD_TEMPLATES = {
      modern: :dashboard_modern,
      geocities: :dashboard_geocities,
      christmas: :dashboard_christmas
    }.freeze

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
        @presence_model ||= Models::Presence.new(
          db,
          present_window_minutes: present_window_minutes,
          ping_interval: ping_interval,
          ping_failure_limit: ping_failure_limit
        )
      end

      def person_model
        @person_model ||= Models::Person.new(db)
      end

      def settings_model
        @settings_model ||= Models::Settings.new(db)
      end

      def present_window_minutes
        settings.scanner.present_window_minutes
      end

      def ping_interval
        settings.scanner.ping_interval
      end
      
      def ping_failure_limit
        settings.scanner.ping_failure_limit
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

      def selected_dashboard_template
        requested = params["template"]&.strip&.downcase&.to_sym
        return requested if requested && DASHBOARD_TEMPLATES.key?(requested)

        DASHBOARD_TEMPLATES.keys.sample
      end
    end

    # Routes - Web Pages
    get "/" do
      data = presence_model.dashboard_data
      template_key = selected_dashboard_template
      view = DASHBOARD_TEMPLATES[template_key] || DASHBOARD_TEMPLATES[:modern]

      erb view, locals: {
        now: Time.now,
        mapped_present: data[:mapped_present],
        mapped_absent: data[:mapped_absent],
        present_count: data[:present_count],
        total_people: data[:total_people],
        top_attendees: data[:top_attendees],
        daily_record: data[:daily_record],
        all_time_record: data[:all_time_record],
        current_week_start: data[:current_week_start],
        current_week_end: data[:current_week_end],
        last_week_winner: data[:last_week_winner],
        show_in_office_tile: settings_model.get_boolean('show_in_office_tile', true),
        show_registered_users_tile: settings_model.get_boolean('show_registered_users_tile', true),
        show_today_record_tile: settings_model.get_boolean('show_today_record_tile', true),
        show_all_time_record_tile: settings_model.get_boolean('show_all_time_record_tile', true),
        template_key: template_key
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
        ping_interval: settings.scanner.ping_interval,
        ping_failure_limit: ping_failure_limit
      )
    end

    get "/api/my-device" do
      ip = client_ip
      device = db[:devices].where(ip: ip).order(Sequel.desc(:last_seen_utc)).first

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
      device = db[:devices].where(ip: ip).order(Sequel.desc(:last_seen_utc)).first

      halt 404, json(error: "No device found with your IP address (#{ip}). Make sure you're connected to the network and have been scanned.") unless device

      existing = person_model.find_by_mac(device[:mac])
      is_update = !existing.nil?
      
      # Only reject if already registered to a DIFFERENT person and it's not an anonymous registration
      if existing && existing[:person] != person_name && !existing[:person].to_s.start_with?("Anonymous")
        halt 409, json(error: "This device is already registered to #{existing[:person]}")
      end

      visible = data["visible"] != false

      person_model.create_or_update(
        mac: device[:mac],
        person: person_name,
        device: device_name || "",
        visible: visible,
        device_id: device[:device_id]
      )

      message = is_update ? "Successfully updated!" : "Successfully registered!"

      json(
        success: true,
        message: message,
        mac: device[:mac],
        person: person_name,
        device: device_name
      )
    rescue StandardError => e
      halt 500, json(error: "Failed to register: #{e.message}")
    end
    
    post "/api/toggle-visibility" do
      ip = client_ip
      device = db[:devices].where(ip: ip).order(Sequel.desc(:last_seen_utc)).first

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

    get "/api/settings" do
      admin_protected!
      json(settings_model.all)
    end

    post "/api/settings" do
      admin_protected!
      data = parse_json_body

      data.each do |key, value|
        settings_model.set(key, value)
      end

      json(success: true, message: "Settings updated successfully")
    rescue StandardError => e
      halt 500, json(error: "Failed to update settings: #{e.message}")
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
