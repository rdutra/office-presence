# frozen_string_literal: true

require "open3"
require "rufus-scheduler"
require "time"

require_relative "utils"
require_relative "config"
require_relative "database"
require_relative "models/device"
require_relative "models/attendance"

module OfficePresence
  class Scanner
    def initialize(config: Config.new, db: Database.connection)
      @config = config
      @db = db
      @device_model = Models::Device.new(db)
      @attendance_model = Models::Attendance.new(db)
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
      run_scan
      @scheduler.every "#{@config.scan_interval}s" do
        run_scan
      end
    end

    def run_scan
      Thread.new do
        @mutex.synchronize do
          begin
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
          
          # Update device
          @device_model.create_or_update(
            mac: mac,
            ip: entry[:ip],
            last_seen_utc: timestamp
          )

          # Record daily attendance
          @attendance_model.record(mac: mac, timestamp: timestamp, date: date)
        end
      end
      log "Updated #{entries.size} hosts at #{timestamp}"
    end

    def log(message)
      return unless debug?
      warn "[DEBUG] #{message}"
    end

  end
end
