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

    def ping_interval
      @config.ping_interval
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
        subnet_entries = run_nmap(subnet)
        warn "[SCANNER] Subnet #{subnet} returned #{subnet_entries.size} entries"
        entries.concat(subnet_entries)
      end

      warn "[SCANNER] Total entries before merge: #{entries.size}"
      entries = merge_entries(entries)
      warn "[SCANNER] Total entries after first merge: #{entries.size}"
      
      arp_map = read_arp_cache

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
      warn "[SCANNER] Added #{arp_only} ARP-only entries"

      # Final merge to eliminate any duplicates created
      merged = merge_entries(entries)
      warn "[SCANNER] Total entries after final merge: #{merged.size}"
      
      merged
    end

    def run_nmap(subnet)
      # Use DNS-SD to discover services and get persistent identifiers
      # -Pn skips host discovery (many devices block ping)
      cmd = ["sudo", "nmap", "-Pn", "-sU", "-p", "5353", "--script=dns-service-discovery", subnet]
      warn "[SCANNER] Running nmap DNS-SD scan on #{subnet} (this may take 60-90 seconds)..."
      start_time = Time.now
      stdout, stderr, _status = Open3.capture3(*cmd)
      elapsed = (Time.now - start_time).round(1)
      warn "[SCANNER] nmap DNS-SD scan completed in #{elapsed}s"
      warn "[SCANNER] nmap stderr: #{stderr.strip}" unless stderr.to_s.strip.empty?
      parse_nmap_dnsd(stdout)
    rescue Errno::ENOENT
      warn "[SCANNER] nmap not found"
      []
    rescue => e
      warn "[SCANNER] nmap error: #{e.message}"
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
    
    def parse_nmap_dnsd(output)
      entries = {}
      current_ip = nil
      current_hostname = nil
      current_device_id = nil
      current_mac = nil
      in_airplay = false
      in_companion_link = false
      
      output.to_s.each_line do |line|
        # Capture IP address
        if line =~ /Nmap scan report for ([\d.]+)/
          # Save previous entry if it exists
          if current_ip
            entries[current_ip] = {
              ip: current_ip,
              mac: current_mac,
              hostname: current_hostname,
              device_id: current_device_id
            }
          end
          
          # Start new entry
          current_ip = $1
          current_hostname = nil
          current_device_id = nil
          current_mac = nil
          in_airplay = false
          in_companion_link = false
          
        # Capture MAC address
        elsif line =~ /MAC Address: ([0-9A-F:]{17})/i
          current_mac = $1
          
        # Detect AirPlay section
        elsif line.include?("7000/tcp airplay:")
          in_airplay = true
          in_companion_link = false
          
        # Detect companion-link section  
        elsif line.include?("companion-link:")
          in_companion_link = true
          in_airplay = false
          
        # Detect other service sections (exit AirPlay/companion-link)
        elsif line =~ /\d+\/tcp \w+:/ && !line.include?("airplay") && !line.include?("companion-link")
          in_airplay = false
          in_companion_link = false
          
        # Capture hostname
        elsif line =~ /hostname: (.+)/i
          hostname = $1.strip
          next if hostname.empty?

          # Ignore raw IP addresses reported as hostnames and prefer readable names
          unless ip_address?(hostname)
            current_hostname = hostname if current_hostname.nil? || ip_address?(current_hostname)
          end
          
        # Capture deviceid from AirPlay
        elsif in_airplay && line =~ /deviceid=([A-F0-9:]{17})/i
          current_device_id ||= $1
          
        # Capture rpBA (Bluetooth address) from companion-link as fallback
        elsif in_companion_link && line =~ /rpBA=([A-F0-9:]{17})/i
          current_device_id ||= $1
        end
      end
      
      # Don't forget the last entry
      if current_ip
        entries[current_ip] = {
          ip: current_ip,
          mac: current_mac,
          hostname: current_hostname,
          device_id: current_device_id
        }
      end
      
      # Log what was found for debugging
      entries.values.each do |entry|
        if entry[:device_id] || entry[:hostname]
          warn "[SCANNER]   Device: #{entry[:ip]} | MAC: #{entry[:mac] || 'none'} | Hostname: #{entry[:hostname] || 'none'} | DeviceID: #{entry[:device_id] || 'none'}"
        end
      end
      
      warn "[SCANNER] Found #{entries.size} devices with DNS-SD data"
      entries.values
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

      # Final deduplication by MAC before storing
      by_mac = {}
      entries.each do |entry|
        mac = Utils.normalize_mac(entry[:mac])
        device_id = entry[:device_id]
        
        # Skip if we have neither MAC nor device_id
        next unless mac || (device_id && !device_id.empty?)
        
        # If we have device_id but no MAC, use device_id as the MAC (primary key)
        mac ||= device_id
        
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
              device_id: device_id
            )

            # Record daily attendance
            @attendance_model.record(mac: mac, timestamp: timestamp, date: date)
          rescue Sequel::UniqueConstraintViolation => e
            warn "[SCANNER] Duplicate key error for entry: IP=#{entry[:ip]} MAC=#{mac} DeviceID=#{device_id} Hostname=#{entry[:hostname]}"
            raise e
          end
        end
      end
      log "Updated #{by_mac.size} hosts at #{timestamp}"
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

    def ip_address?(value)
      value.to_s.match?(/\A(?:\d{1,3}\.){3}\d{1,3}\z/)
    end

    def log(message)
      return unless debug?
      warn "[DEBUG] #{message}"
    end

  end
end
