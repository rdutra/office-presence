# frozen_string_literal: true

require "rufus-scheduler"
require "time"

require_relative "utils"
require_relative "config"
require_relative "database"
require_relative "models/device"
require_relative "models/attendance"
require_relative "models/person"
require_relative "services/network_discovery"

module OfficePresence
  class Scanner
    def initialize(config: Config.new, db: Database.connection)
      @config = config
      @db = db
      @device_model = Models::Device.new(db)
      @attendance_model = Models::Attendance.new(db)
      @person_model = Models::Person.new(db)
      @mutex = Mutex.new
      @scheduler = Rufus::Scheduler.new
      @started = false
      @discovery_service = Services::NetworkDiscovery.new(logger: @config.logger)
    end

    def start
      return if @started

      @started = true
      schedule_scans
    end

    def present_window_minutes
      @config.present_window_minutes
    end

    def ping_interval
      @config.ping_interval
    end

    def ping_failure_limit
      @config.ping_failure_limit
    end

    def debug?
      @config.debug?
    end

    def db
      @db
    end

    private

    def schedule_scans
      # TIER 1: Quick ARP check - detects new arrivals instantly
      @scheduler.every "#{@config.arp_check_interval}s" do
        quick_arp_check
      end

      # TIER 2: Ping known devices - validates continued presence
      @scheduler.every "#{@config.ping_interval}s" do
        ping_registered_devices
      end

      # TIER 3: Full nmap scan every 15 minutes - comprehensive backup scan
      # Mainly refreshes ARP cache for devices not actively communicating
      Thread.new { run_scan }  # Run immediately on startup
      @scheduler.every "15m" do
        run_scan
      end
    end

    def run_scan
      Thread.new do
        begin
          entries = collect_entries
          store_entries_safely(entries)
        rescue => e
          backtrace = Array(e.backtrace).first(5).join("\n")
          log_error "Scanner error: #{e.class}: #{e.message}\n#{backtrace}"
        end
      end
    end

    def collect_entries
      entries = []
      @config.subnets.each do |subnet|
        subnet_entries = @discovery_service.run_nmap(subnet)
        log_info "[SCANNER] Subnet #{subnet} returned #{subnet_entries.size} entries"
        entries.concat(subnet_entries)
      end

      log_debug "[SCANNER] Total entries before merge: #{entries.size}"
      entries = merge_entries(entries)
      log_debug "[SCANNER] Total entries after first merge: #{entries.size}"
      
      arp_map = @discovery_service.read_arp_cache

      # First pass: fill in missing MACs from ARP cache
      entries.each do |entry|
        if entry[:mac].nil? || entry[:mac].empty?
          arp_mac = arp_map[entry[:ip]]
          entry[:mac] = Utils.normalize_mac(arp_mac) if arp_mac
        else
          entry[:mac] = Utils.normalize_mac(entry[:mac])
        end
      end

      # Second pass: add ARP-only entries (devices not found by nmap)
      arp_only = 0
      arp_map.each do |ip, mac|
        next if entries.any? { |entry| entry[:ip] == ip }
        mac_norm = Utils.normalize_mac(mac)
        next if mac_norm.nil? || mac_norm == "ff:ff:ff:ff:ff:ff"
        entries << { ip: ip, mac: mac_norm, hostname: nil, device_id: nil }
        arp_only += 1
      end
      log_debug "[SCANNER] Added #{arp_only} ARP-only entries"

      # Final merge to eliminate any duplicates created
      merged = merge_entries(entries)
      log_debug "[SCANNER] Total entries after final merge: #{merged.size}"
      
      merged
    end

    def merge_entries(entries)
      # First pass: merge by IP
      by_ip = {}
      entries.each do |entry|
        ip = entry[:ip]
        next if ip.nil?
        
        current = by_ip[ip] ||= { ip: ip, mac: nil, hostname: nil, device_id: nil }
        current[:mac] ||= entry[:mac]
        current[:hostname] ||= entry[:hostname]
        current[:device_id] ||= entry[:device_id]
      end
      
      # Second pass: deduplicate by MAC or device_id
      by_key = {}
      by_ip.values.each do |entry|
        mac = entry[:mac]
        device_id = entry[:device_id]
        
        # Create unique key for deduplication
        # Priority: device_id > mac
        key = nil
        if device_id && !device_id.empty?
          key = "devid:#{device_id}"
        elsif mac && !mac.empty?
          key = "mac:#{mac}"
        end
        
        next unless key
        
        if by_key[key]
          # Merge with existing - keep most complete data
          existing = by_key[key]
          existing[:hostname] ||= entry[:hostname]
          existing[:device_id] ||= entry[:device_id]
          existing[:mac] ||= entry[:mac]
          existing[:ip] ||= entry[:ip]
        else
          by_key[key] = entry
        end
      end
      
      by_key.values
    end

    def store_entries(entries, reset_ping_failures: false)
      timestamp = Time.now.utc.iso8601.gsub(/\+00:00\z/, "Z")
      date = Time.now.utc.strftime("%Y-%m-%d")

      # Final deduplication by MAC before storing
      by_mac = {}
      entries.each do |entry|
        mac = Utils.normalize_mac(entry[:mac])
        device_id = entry[:device_id]

        # Only store entries that provide a valid MAC. Device IDs are tracked
        # separately and should never be used as a surrogate MAC/value.
        next unless mac

        # Keep only one entry per MAC (last one wins)
        by_mac[mac] = entry.merge(mac: mac)
      end

      @db.transaction do
        by_mac.each do |mac, entry|
          device_id = entry[:device_id]

          begin
            # Store all fields including device_id and hostname
            @device_model.create_or_update(
              mac: mac,
              ip: entry[:ip],
              last_seen_utc: timestamp,
              hostname: entry[:hostname],
              device_id: device_id,
              reset_ping_failures: reset_ping_failures
            )

            # Record daily attendance
            @attendance_model.record(mac: mac, timestamp: timestamp, date: date)

            # Auto-map devices with a persistent device_id to anonymous people
            ensure_anonymous_person(mac: mac, device_id: device_id, hostname: entry[:hostname])
          rescue Sequel::UniqueConstraintViolation => e
            log_error "[SCANNER] Duplicate key error for entry: IP=#{entry[:ip]} MAC=#{mac} DeviceID=#{device_id} Hostname=#{entry[:hostname]}"
            raise e
          end
        end
      end
      log_info "Updated #{by_mac.size} hosts at #{timestamp}"
    end

    # Helper to safely store entries with mutex protection
    def store_entries_safely(entries, reset_ping_failures: false)
      return if entries.empty?

      @mutex.synchronize do
        store_entries(entries, reset_ping_failures: reset_ping_failures)
      end
    end

    # Calculate the cutoff timestamp for the present window
    def present_window_cutoff
      cutoff_time = Time.now.utc - (present_window_minutes * 60)
      cutoff_time.iso8601.gsub(/\+00:00\z/, "Z")
    end

    # Get list of registered device MAC addresses
    def registered_macs
      @person_model.all.map { |p| p[:mac] }
    end

    # Wrapper for running scan operations in a background thread with error handling
    def run_in_thread(operation_name, &block)
      Thread.new do
        begin
          yield
        rescue => e
          log_error "#{operation_name} error: #{e.class}: #{e.message}"
        end
      end
    end

    def quick_arp_check
      run_in_thread("Quick ARP check") do
        log_debug "Quick ARP check starting..."

        arp_map = @discovery_service.read_arp_cache
        cutoff = present_window_cutoff
        known_macs = registered_macs

        entries = []
        new_count = 0
        reconnected_count = 0

        arp_map.each do |ip, mac|
          mac_norm = Utils.normalize_mac(mac)
          next if mac_norm.nil? || mac_norm == "ff:ff:ff:ff:ff:ff"

          if known_macs.include?(mac_norm)
            device = @device_model.find_by_mac(mac_norm)

            if device.nil?
              entries << { ip: ip, mac: mac_norm, hostname: nil }
              log_info "  → Registered device #{mac_norm} detected in ARP (first time)"
              new_count += 1
            elsif device[:last_seen_utc].nil? || device[:last_seen_utc] < cutoff
              entries << { ip: ip, mac: mac_norm, hostname: nil }
              log_info "  → Registered device #{mac_norm} reconnected via ARP"
              reconnected_count += 1
            end
          else
            # Unmapped device - track via ARP as usual
            existing = @device_model.find_by_mac(mac_norm)
            new_count += 1 if existing.nil?
            entries << { ip: ip, mac: mac_norm, hostname: nil }
          end
        end

        store_entries_safely(entries)

        if entries.empty?
          log_debug "Quick ARP check: no new devices in cache"
        elsif new_count > 0 || reconnected_count > 0
          log_info "Quick ARP check: #{new_count} NEW devices, #{reconnected_count} reconnected, #{entries.size} total updated"
        else
          log_debug "Quick ARP check: updated #{entries.size} devices"
        end
      end
    end

    def ping_registered_devices
      run_in_thread("Ping validation") do
        log_debug "Ping validation starting..."

        known_macs = registered_macs

        if known_macs.empty?
          log_debug "Ping validation: no registered devices"
          return
        end

        cutoff = present_window_cutoff

        # Get only PRESENT devices (last_seen within window)
        devices_to_check = @db[:devices]
          .where(mac: known_macs)
          .where { last_seen_utc >= cutoff }
          .select(:mac, :ip)
          .all

        log_debug "Ping validation: checking #{devices_to_check.size} present devices (out of #{known_macs.size} registered)"

        ips = devices_to_check.map { |d| d[:ip] }.compact
        responding_ips = @discovery_service.ping_hosts_batch(ips)
        
        # Create entries for responding devices
        entries = []
        failure_limit = ping_failure_limit

        devices_to_check.each do |device|
          if responding_ips.include?(device[:ip])
            entries << { ip: device[:ip], mac: device[:mac], hostname: nil }
            log_debug "  ✓ #{device[:mac]} (#{device[:ip]}) is responding"
          else
            failure_count = @device_model.increment_ping_failure(device[:mac], limit: failure_limit)
            log_debug "  ✗ #{device[:mac]} (#{device[:ip]}) not responding (#{failure_count}/#{failure_limit})"
            if failure_count >= failure_limit
              log_info "Ping validation: #{device[:mac]} marked offline after #{failure_count} failed attempts"
            end
          end
        end

        store_entries_safely(entries, reset_ping_failures: true)
        log_debug "Ping validation complete: #{entries.size}/#{devices_to_check.size} devices responded"
      end
    end

    def ip_address?(value)
      value.to_s.match?(/\A(?:\d{1,3}\.){3}\d{1,3}\z/)
    end

    def ensure_anonymous_person(mac:, device_id:, hostname:)
      # If device_id is missing, we still want to map to an anonymous user
      # to prevent them from showing as a totally unknown/untracked device.
      
      # Try looking up by MAC first
      return if @person_model.find_by_mac(mac)
      
      # If device_id exists, see if it's already registered under another MAC
      if device_id && !device_id.empty?
        return if @person_model.find_by_device_id(device_id)
      end

      @person_model.create_or_update(
        mac: mac,
        person: anonymous_label(device_id, mac),
        device: anonymous_device_name(hostname),
        visible: true,
        device_id: device_id
      )
    end

    def anonymous_label(device_id, mac)
      if device_id && !device_id.empty?
        hex = device_id.gsub(/[^0-9A-Fa-f]/, "")
        suffix = hex[-4, 4]&.rjust(4, '0')
      else
        # Fallback to the last 4 characters of the MAC address
        hex = mac.gsub(/[^0-9A-Fa-f]/, "")
        suffix = hex[-4, 4]&.rjust(4, '0')
      end

      suffix ? "Anonymous #{suffix.upcase}" : "Anonymous"
    end

    def anonymous_device_name(hostname)
      # Keep the public device label generic to preserve anonymity
      "Auto-detected device"
    end

    def log_info(message)
      @config.logger.info(message)
    end

    def log_error(message)
      @config.logger.error(message)
    end

    def log_debug(message)
      @config.logger.debug(message)
    end

  end
end
