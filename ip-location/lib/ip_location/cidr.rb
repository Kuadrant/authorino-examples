# frozen_string_literal: true

module IpLocation
  module CIDR
    module_function

    def to_bin(s)
      parts = s.split('.').map(&:to_i)
      parts.map { |part| part.to_s(2).rjust(8, '0') }.join
    end

    def from_bin(s)
      [s[0, 8], s[8, 8], s[16, 8], s[24, 8]].map { |part| part.to_i(2) }.join('.')
    end

    def to_range_bin(cidr)
      ip, suffix = cidr.split('/')
      power = 32 - suffix.to_i
      ip_bin = to_bin(ip)
      [ip_bin, "#{ip_bin[0, 32-power]}#{'1' * power}"]
    end

    def to_range(cidr)
      to_range_bin(cidr).map { |ip| from_bin(ip) }
    end
  end
end

