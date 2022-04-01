# frozen_string_literal: true

module IpLocation
  class Locator
    def initialize(db)
      @db = db
    end

    attr_reader :db

    def call(ip)
      ip_as_num = CIDR.to_bin(ip).to_i(2)
      sql = <<~SQL
        SELECT
          locations.continent_code,
          locations.continent_name,
          locations.country_iso_code,
          locations.country_name,
          locations.is_in_european_union
        FROM netblocks
          INNER JOIN locations ON netblocks.geoname_id = locations.geoname_id
        WHERE
          netblocks.range_start <= ?
          AND netblocks.range_end >= ?
      SQL
      results = db.query(sql, ip_as_num, ip_as_num)
      data = results.first
      return if !data || data.empty?
      data['is_in_european_union'] = data['is_in_european_union'] == 1
      data
    end
  end
end
