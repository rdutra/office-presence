# frozen_string_literal: true

require "csv"
require "open3"
require "rufus-scheduler"
require "time"

require_relative "utils"
require_relative "config"
require_relative "database"
require_relative "models/device"
require_relative "models/person"
require_relative "models/attendance"

module OfficePresence
  class Scanner
    def initialize(config: Config.new, db: Database.connection)
      @config = config
      @db = db
      @device_model = Models::Device.new(db)
      @person_model = Models::Person.new(db)
      @attendance_model = Models::Attendance.new(db)
      @mutex = Mutex.new
      @scheduler = Rufus::Scheduler.new
      @people_mtime = nil
      @started = false
      @ping_mutex = Mutex.new
      @ping_running = false
      @arp_mutex = Mutex.new
      @arp_running = false
    end

    def start
      return if @started

      @started = true
      load_people_mapping
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
      # TIER 1: Quick ARP check every 5 seconds - detects new arrivals instantly
      @scheduler.every "5s" do
        quick_arp_check
      end

      # TIER 2: Ping known devices every 10 seconds - validates continued presence
      @scheduler.every "10s" do
        ping_registered_devices
      end

      # TIER 3: Full nmap scan every 15 minutes - comprehensive backup scan
      run_scan  # Run immediately on startup
      @scheduler.every "15m" do
        run_scan
      end
    end

    def run_scan
      Thread.new do
        @mutex.synchronize do
          begin
            load_people_mapping
            entries = collect_entries
            store_entries(entries)
          rescue => e
            backtrace = Array(e.backtrace).first(5).join("\n")
            log "Scanner error: #{e.class}: #{e.message}\n#{backtrace}"
          end
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

    def load_people_mapping
      mtime = File.exist?(Models::Person::PEOPLE_CSV) ? File.mtime(Models::Person::PEOPLE_CSV) : nil
      return if mtime == @people_mtime

      @person_model.load_from_csv
      @people_mtime = mtime
      log "people.csv loaded (#{mtime})"
    end

    def run_nmap(subnet)
      cmd = ["nmap", "-sn", "-n", "-T4", "--min-rate", "100", subnet, "-oG", "-"]
      log "Running: #{cmd.join(' ')}"
      stdout, stderr, status = Open3.capture3(*cmd)
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

    def quick_arp_check
      # Skip if already running (atomic check)
      return unless @arp_mutex.try_lock

      begin
        @arp_running = true
        @mutex.synchronize do
          begin
            log "Quick ARP check starting..."
            arp_map = read_arp_cache

            # Calculate cutoff time for present window
            cutoff_time = Time.now.utc - (present_window_minutes * 60)
            cutoff_string = cutoff_time.iso8601.gsub(/\+00:00\z/, "Z")

            # Get list of known/registered MACs from people table using model
            known_macs = @person_model.all.map { |p| p[:mac] }

            entries = []
            new_count = 0
            reconnected_count = 0

            arp_map.each do |ip, mac|
              mac_norm = Utils.normalize_mac(mac)
              next if mac_norm.nil? || mac_norm == "ff:ff:ff:ff:ff:ff"

              if known_macs.include?(mac_norm)
                # This is a registered device - check if it's currently absent
                device = @device_model.find_by_mac(mac_norm)

                if device.nil?
                  # Device never seen before - add it
                  entries << { ip: ip, mac: mac_norm, hostname: nil }
                  log "  → Registered device #{mac_norm} detected in ARP (first time)"
                  new_count += 1
                else
                  # Check if device is currently absent (beyond present window)
                  last_seen = device[:last_seen_utc]
                  if last_seen.nil? || last_seen < cutoff_string
                    entries << { ip: ip, mac: mac_norm, hostname: nil }
                    log "  → Registered device #{mac_norm} reconnected via ARP"
                    reconnected_count += 1
                  end
                  # If device is already present, skip it (let ping handle it)
                end
              else
                # Unmapped device - track via ARP as usual
                existing = @device_model.find_by_mac(mac_norm)
                new_count += 1 if existing.nil?
                entries << { ip: ip, mac: mac_norm, hostname: nil }
              end
            end

            unless entries.empty?
              store_entries(entries)
              if new_count > 0 || reconnected_count > 0
                log "Quick ARP check: #{new_count} NEW devices, #{reconnected_count} reconnected, #{entries.size} total updated"
              else
                log "Quick ARP check: updated #{entries.size} devices"
              end
            else
              log "Quick ARP check: no new devices in cache"
            end
          rescue => e
            log "Quick ARP check error: #{e.class}: #{e.message}"
          end
        end
      ensure
        @arp_running = false
        @arp_mutex.unlock
      end
    end

    def ping_registered_devices
      # Skip if already running (atomic check)
      return unless @ping_mutex.try_lock

      begin
        @ping_running = true
        log "Ping validation starting..."

        # Calculate cutoff time - only ping devices seen within present_window
        cutoff_time = Time.now.utc - (present_window_minutes * 60)
        cutoff_string = cutoff_time.iso8601.gsub(/\+00:00\z/, "Z")

        # Get all known MACs from people table using model
        known_macs = @person_model.all.map { |p| p[:mac] }

        if known_macs.empty?
          log "Ping validation: no registered devices"
        else

          # Get only PRESENT devices (last_seen within window)
          devices_to_check = @db[:devices]
            .where(mac: known_macs)
            .where { last_seen_utc >= cutoff_string }
            .select(:mac, :ip)
            .all

          log "Ping validation: checking #{devices_to_check.size} present devices (out of #{known_macs.size} registered)"

          entries = []

          devices_to_check.each do |device|
            next unless device[:ip]

            # Quick ping check (1 second timeout)
            if ping_host(device[:ip])
              entries << {
                ip: device[:ip],
                mac: device[:mac],
                hostname: nil
              }
              log "  ✓ #{device[:mac]} (#{device[:ip]}) is responding"
            else
              log "  ✗ #{device[:mac]} (#{device[:ip]}) not responding"
            end
          end

          @mutex.synchronize do
            store_entries(entries) unless entries.empty?
          end

          log "Ping validation complete: #{entries.size}/#{devices_to_check.size} devices responded"
        end
      rescue => e
        log "Ping validation error: #{e.class}: #{e.message}"
      ensure
        @ping_running = false
        @ping_mutex.unlock
      end
    end

    def ping_host(ip)
      # -c 1: one packet, -W 1: 1 second timeout, -q: quiet mode
      system("ping", "-c", "1", "-W", "1", "-q", ip, out: File::NULL, err: File::NULL)
    end

    def log(message)
      return unless debug?
      warn "[DEBUG] #{message}"
    end

  end
end
