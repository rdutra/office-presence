# frozen_string_literal: true

require "open3"
require "time"
require_relative "../utils"

module OfficePresence
  module Services
    class NetworkDiscovery
      def initialize(logger: nil)
        @logger = logger
      end

      def run_nmap(subnet)
        # Use DNS-SD to discover services and get persistent identifiers
        # -Pn skips host discovery (many devices block ping)
        cmd = ["sudo", "nmap", "-Pn", "-sU", "-p", "5353", "--script=dns-service-discovery", subnet]
        log_info "[SCANNER] Running nmap DNS-SD scan on #{subnet} (this may take 60-90 seconds)..."
        start_time = Time.now
        stdout, stderr, _status = Open3.capture3(*cmd)
        elapsed = (Time.now - start_time).round(1)
        log_info "[SCANNER] nmap DNS-SD scan completed in #{elapsed}s"
        log_warn "[SCANNER] nmap stderr: #{stderr.strip}" unless stderr.to_s.strip.empty?
        parse_nmap_dnsd(stdout)
      rescue Errno::ENOENT
        log_warn "[SCANNER] nmap not found"
        []
      rescue => e
        log_warn "[SCANNER] nmap error: #{e.message}"
        []
      end

      def read_arp_cache
        mapping = {}
        stdout, stderr, status = Open3.capture3("/usr/sbin/arp", "-an")
        unless status.success?
          log_warn "arp error: #{stderr.strip}"
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
        log_warn "read_arp_cache error: #{e.message}"
        {}
      end

      def ping_hosts_batch(ips)
        return [] if ips.empty?

        # fping options:
        # -c1: send 1 ping packet
        # -t 750: timeout of 750ms (slightly less than 1 second to match original behavior)
        # -q: quiet mode (only show summary)
        # -A: show targets by address (not hostname)
        result = `fping -c1 -t 750 -q -A #{ips.join(' ')} 2>&1`

        responding_ips = []

        # Parse fping output - alive hosts will have lines like "192.168.1.1 : xmt/rcv/%loss = 1/1/0%"
        result.each_line do |line|
          if line =~ /^(\S+)\s+:\s+xmt\/rcv\/%loss\s+=\s+\d+\/(\d+)/
            ip = $1
            received = $2.to_i
            responding_ips << ip if received > 0
          end
        end

        responding_ips
      end

      private

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
            log_warn "[SCANNER]   Device: #{entry[:ip]} | MAC: #{entry[:mac] || 'none'} | Hostname: #{entry[:hostname] || 'none'} | DeviceID: #{entry[:device_id] || 'none'}"
          end
        end
        
        log_warn "[SCANNER] Found #{entries.size} devices with DNS-SD data"
        entries.values
      end

      def ip_address?(value)
        value.to_s.match?(/\A(?:\d{1,3}\.){3}\d{1,3}\z/)
      end

      def log_info(msg)
        @logger&.info(msg) || warn(msg)
      end

      def log_warn(msg)
        @logger&.warn(msg) || warn(msg)
      end
    end
  end
end
