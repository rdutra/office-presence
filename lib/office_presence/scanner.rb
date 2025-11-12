# frozen_string_literal: true

require "open3"
require "rufus-scheduler"
require "time"

require_relative "utils"
require_relative "config"
require_relative "database"
require_relative "models/device"
require_relative "models/attendance"
require_relative "models/person"

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
    end

    def start
      return if @started

      @started = true
      schedule_scans
    end

    def present_window_minutes
      @config.present_window_minutes
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
          log "Scanner error: #{e.class}: #{e.message}\n#{backtrace}"
        end
      end
    end

    def collect_entries
      entries = []
      @config.subnets.each do |subnet|
        entries.concat(run_nmap(subnet))
      end

      entries = merge_entries(entries)
      arp_map = read_arp_cache

      if entries.empty? && !arp_map.empty?
        arp_map.each do |ip, mac|
          mac_norm = Utils.normalize_mac(mac)
          next if mac_norm.nil? || mac_norm == "ff:ff:ff:ff:ff:ff"
          entries << { ip: ip, mac: mac_norm }
        end
      else
        entries.each do |entry|
          mac_norm = Utils.normalize_mac(entry[:mac])
          if mac_norm.nil?
            arp_mac = arp_map[entry[:ip]]
            entry[:mac] = Utils.normalize_mac(arp_mac)
          else
            entry[:mac] = mac_norm
          end
        end

        arp_map.each do |ip, mac|
          next if entries.any? { |entry| entry[:ip] == ip }
          mac_norm = Utils.normalize_mac(mac)
          next if mac_norm.nil? || mac_norm == "ff:ff:ff:ff:ff:ff"
          entries << { ip: ip, mac: mac_norm }
        end
      end

      entries
    end

    def run_nmap(subnet)
      cmd = ["nmap", "-sn", "-n", "-T4", "--min-rate", "100", subnet, "-oG", "-"]
      log "Running nmap scan on #{subnet} (this may take 30-60 seconds)..."
      start_time = Time.now
      stdout, stderr, status = Open3.capture3(*cmd)
      elapsed = (Time.now - start_time).round(1)
      log "nmap scan completed in #{elapsed}s"
      log "nmap stderr: #{stderr.strip}" unless stderr.to_s.strip.empty?
      parse_nmap(stdout)
    rescue Errno::ENOENT
      log "nmap not found"
      []
    rescue => e
      log "nmap error: #{e.message}"
      []
    end

    def parse_nmap(output)
      entries = {}
      output.to_s.each_line do |line|
        next unless line.start_with?("Host: ")
        parts = line.split
        ip = parts[1]
        mac = if line.include?("MAC Address:")
                line.split("MAC Address:")[1].split.first rescue nil
              end
        current = entries[ip] || { ip: ip, mac: nil }
        current[:mac] = mac unless mac.to_s.empty?
        entries[ip] = current
      end
      entries.values
    end

    def merge_entries(entries)
      merged = {}
      entries.each do |entry|
        ip = entry[:ip]
        next if ip.nil?
        current = merged[ip] ||= { ip: ip, mac: nil }
        current[:mac] = entry[:mac] if entry[:mac]
      end
      merged.values
    end

    def read_arp_cache
      mapping = {}
      stdout, stderr, status = Open3.capture3("/usr/sbin/arp", "-an")
      unless status.success?
        log "arp error: #{stderr.strip}"
        return mapping
      end

      stdout.each_line do |line|
        next unless (match = line.match(/\(([^)]+)\)\s+at\s+([0-9a-f:\-]{11,17}|<incomplete>)/i))
        ip = match[1]
        mac = match[2]
        next if mac.casecmp("<incomplete>").zero?
        mac_norm = Utils.normalize_mac(mac)
        mapping[ip] = mac_norm if mac_norm
      end
      mapping
    rescue => e
      log "read_arp_cache error: #{e.message}"
      {}
    end

    def store_entries(entries)
      timestamp = Time.now.utc.iso8601.gsub(/\+00:00\z/, "Z")
      date = Time.now.utc.strftime("%Y-%m-%d")

      @db.transaction do
        entries.each do |entry|
          mac = Utils.normalize_mac(entry[:mac])
          next unless mac  # Skip entries without a valid MAC address

          # Update device using model
          @device_model.create_or_update(
            mac: mac,
            ip: entry[:ip],
            last_seen_utc: timestamp
          )

          # Record daily attendance using model
          @attendance_model.record(mac: mac, timestamp: timestamp, date: date)
        end
      end
      log "Updated #{entries.size} hosts at #{timestamp}"
    end

    # Helper to safely store entries with mutex protection
    def store_entries_safely(entries)
      return if entries.empty?

      @mutex.synchronize do
        store_entries(entries)
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
          log "#{operation_name} error: #{e.class}: #{e.message}"
        end
      end
    end

    def quick_arp_check
      run_in_thread("Quick ARP check") do
        log "Quick ARP check starting..."

        arp_map = read_arp_cache
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
              log "  → Registered device #{mac_norm} detected in ARP (first time)"
              new_count += 1
            elsif device[:last_seen_utc].nil? || device[:last_seen_utc] < cutoff
              entries << { ip: ip, mac: mac_norm, hostname: nil }
              log "  → Registered device #{mac_norm} reconnected via ARP"
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
          log "Quick ARP check: no new devices in cache"
        elsif new_count > 0 || reconnected_count > 0
          log "Quick ARP check: #{new_count} NEW devices, #{reconnected_count} reconnected, #{entries.size} total updated"
        else
          log "Quick ARP check: updated #{entries.size} devices"
        end
      end
    end

    def ping_registered_devices
      run_in_thread("Ping validation") do
        log "Ping validation starting..."

        known_macs = registered_macs

        if known_macs.empty?
          log "Ping validation: no registered devices"
          return
        end

        cutoff = present_window_cutoff

        # Get only PRESENT devices (last_seen within window)
        devices_to_check = @db[:devices]
          .where(mac: known_macs)
          .where { last_seen_utc >= cutoff }
          .select(:mac, :ip)
          .all

        log "Ping validation: checking #{devices_to_check.size} present devices (out of #{known_macs.size} registered)"

        entries = ping_hosts_batch(devices_to_check)

        store_entries_safely(entries)
        log "Ping validation complete: #{entries.size}/#{devices_to_check.size} devices responded"
      end
    end

    def ping_hosts_batch(devices)
      ips = devices.map { |d| d[:ip] }.compact
      return [] if ips.empty?

      # Create a mapping of IP to device info for quick lookup
      ip_to_device = devices.each_with_object({}) do |device, hash|
        hash[device[:ip]] = device if device[:ip]
      end

      # fping options:
      # -c1: send 1 ping packet
      # -t 750: timeout of 750ms (slightly less than 1 second to match original behavior)
      # -q: quiet mode (only show summary)
      # -A: show targets by address (not hostname)
      result = `fping -c1 -t 750 -q -A #{ips.join(' ')} 2>&1`

      entries = []

      # Parse fping output - alive hosts will have lines like "192.168.1.1 : xmt/rcv/%loss = 1/1/0%"
      result.each_line do |line|
        if line =~ /^(\S+)\s+:\s+xmt\/rcv\/%loss\s+=\s+\d+\/(\d+)/
          ip = $1
          received = $2.to_i

          if received > 0 && ip_to_device[ip]
            device = ip_to_device[ip]
            entries << { ip: device[:ip], mac: device[:mac], hostname: nil }
            log "  ✓ #{device[:mac]} (#{device[:ip]}) is responding"
          end
        end
      end

      # Log devices that didn't respond
      ips.each do |ip|
        unless entries.any? { |e| e[:ip] == ip }
          device = ip_to_device[ip]
          log "  ✗ #{device[:mac]} (#{ip}) not responding" if device
        end
      end

      entries
    end

    def log(message)
      return unless debug?
      warn "[DEBUG] #{message}"
    end

  end
end
