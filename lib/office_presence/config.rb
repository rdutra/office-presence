# frozen_string_literal: true

require "logger"
require_relative "utils"

module OfficePresence
  class Config
    DEFAULT_SUBNET = "192.168.1.0/24"

    attr_reader :logger

    def initialize(env = ENV)
      @env = env
      @logger = Logger.new($stdout)
      @logger.level = debug? ? Logger::DEBUG : Logger::INFO
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
      end
    end

    def scan_interval
      integer_env("SCAN_INTERVAL", 120, 10..86_400)
    end

    def present_window_minutes
      integer_env("PRESENT_WINDOW_MINUTES", 10, 1..(24 * 60))
    end

    def arp_check_interval
      integer_env("ARP_CHECK_INTERVAL", 5, 1..300)
    end

    def ping_interval
      integer_env("PING_INTERVAL", 10, 1..300)
    end

    def subnets
      list = Utils.split_env_list(@env["SUBNETS"] || @env["SUBNET"])
      list.empty? ? [DEFAULT_SUBNET] : list
    end

    def debug?
      (@env["DEBUG"] || "0") == "1"
    end

    private

    def integer_env(key, default, range)
      value = @env[key]
      number = value.to_i
      number = default if value.nil? || value.to_s.strip.empty?
      number = default unless range.include?(number)
      number
    end
  end
end
