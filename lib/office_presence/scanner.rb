# frozen_string_literal: true

require "csv"
require "open3"
require "rufus-scheduler"
require "time"

require_relative "utils"
require_relative "config"
require_relative "database"

module OfficePresence
  class Scanner
    def initialize(config: Config.new, db: Database.connection)
      @config = config
      @db = db
      @mutex = Mutex.new
      @scheduler = Rufus::Scheduler.new
      @people_mtime = nil
      @started = false
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
      run_scan
      @scheduler.every "#{@config.scan_interval}s" do
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
          entries << { ip: ip, mac: mac_norm, hostname: nil }
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
          entries << { ip: ip, mac: mac_norm, hostname: nil }
        end
      end

      entries
    end

    def load_people_mapping
      mtime = File.exist?(PEOPLE_CSV) ? File.mtime(PEOPLE_CSV) : nil
      return if mtime == @people_mtime

      @db.transaction do
        @db[:people].truncate
        if mtime
          CSV.foreach(PEOPLE_CSV, headers: true) do |row|
            mac = Utils.normalize_mac(row["mac_address"])
            next unless mac
            @db[:people].insert_conflict(target: :mac, update: {
              person: row["person"].to_s.strip,
              device: row["device"].to_s.strip
            }).insert(
              mac: mac,
              person: row["person"].to_s.strip,
              device: row["device"].to_s.strip
            )
          end
        end
      end

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
        hostname = line[/\(([^)]+)\)/, 1]
        mac = if line.include?("MAC Address:")
                line.split("MAC Address:")[1].split.first rescue nil
              end
        current = entries[ip] || { ip: ip, hostname: nil, mac: nil }
        current[:hostname] = hostname unless hostname.to_s.empty?
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
        current = merged[ip] ||= { ip: ip, hostname: nil, mac: nil }
        current[:hostname] = entry[:hostname] if entry[:hostname]
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
          
          ip = entry[:ip]
          hostname = entry[:hostname]

          existing = @db[:devices].where(mac: mac).first
          if existing
            updates = { last_seen_utc: timestamp }
            updates[:ip] = ip if ip && !ip.empty?
            updates[:hostname] = hostname if hostname && !hostname.empty?
            @db[:devices].where(mac: mac).update(updates)
          else
            @db[:devices].insert(
              mac: mac,
              ip: ip,
              hostname: hostname,
              last_seen_utc: timestamp
            )
          end

          # Record daily attendance
          attendance = @db[:attendance].where(mac: mac, date: date).first
          if attendance
            @db[:attendance].where(mac: mac, date: date).update(last_seen_utc: timestamp)
          else
            @db[:attendance].insert(
              mac: mac,
              date: date,
              first_seen_utc: timestamp,
              last_seen_utc: timestamp
            )
          end
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
