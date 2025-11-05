# frozen_string_literal: true

module OfficePresence
  module Utils
    module_function

    def split_env_list(raw)
      return [] if raw.nil? || raw.strip.empty?
      raw.to_s.split(/[;,\s]+/).map(&:strip).reject(&:empty?)
    end

    def normalize_mac(mac)
      return nil if mac.nil?
      value = mac.strip.downcase.tr("-", ":")
      parts = value.split(":")
      parts = parts.map { |part| part.rjust(2, "0") } if parts.length == 6
      value = parts.join(":") if parts.length == 6
      return value if value.match?(/\A([0-9a-f]{2}:){5}[0-9a-f]{2}\z/)
      nil
    end
  end
end
