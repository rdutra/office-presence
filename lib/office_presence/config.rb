# frozen_string_literal: true

require_relative "utils"

module OfficePresence
  class Config
    DEFAULT_SUBNET = "192.168.1.0/24"

    def initialize(env = ENV)
      @env = env
    end

    def scan_interval
      integer_env("SCAN_INTERVAL", 120, 10..86_400)
    end

    def present_window_minutes
      integer_env("PRESENT_WINDOW_MINUTES", 30, 1..(24 * 60))
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
