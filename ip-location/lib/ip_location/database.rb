# frozen_string_literal: true

require 'csv'
require 'sqlite3'

module IpLocation
  class Database
    LOCATIONS_COLUMNS = {
      geoname_id: 'INTEGER',
      continent_code: 'TEXT',
      continent_name: 'TEXT',
      country_iso_code: 'TEXT',
      country_name: 'TEXT',
      is_in_european_union: 'INTEGER'
    }.freeze

    def initialize(db_file_path)
      @connection = SQLite3::Database.open(db_file_path)
      @connection.results_as_hash = true

      create_schema!
    end

    def import_locations(csv_path)
      puts 'Importing locations...'
      connection.execute 'DELETE FROM locations'
      colum_names = LOCATIONS_COLUMNS.keys.map(&:to_s)
      column_names_sql = colum_names.join(',')
      placeholders = Array.new(colum_names.size, '?').join(',')
      i = 0
      CSV.foreach(csv_path, headers: true) do |row|
        values = row.fields(*colum_names)
        connection.execute "INSERT INTO locations (#{column_names_sql}) VALUES (#{placeholders})", *values
        printf "\rLocations imported: #{i}"
        i += 1
      end
      puts ''
    end

    def import_netblocks(csv_path)
      puts 'Importing netblocks...'
      connection.execute 'DELETE FROM netblocks'
      i = 0
      CSV.foreach(csv_path, headers: true) do |row|
        range = CIDR.to_range_bin(row['network']).map { |bin| bin.to_i(2) }
        values = [range, row['geoname_id']].flatten
        connection.execute 'INSERT INTO netblocks (range_start, range_end, geoname_id) VALUES (?, ?, ?)', *values
        printf "\rNetblocks imported: #{i}"
        i += 1
      end
      puts ''
    end

    %i[query execute].each do |method_sym|
      define_method(method_sym) do |*args, &block|
        connection.public_send(method_sym, *args, &block)
      end
    end

    protected

    attr_reader :connection

    def create_schema!
      # locations
      connection.execute <<~SQL
        CREATE TABLE IF NOT EXISTS locations(#{LOCATIONS_COLUMNS.to_a.map { |col| col.join(' ') }.join(',')})
      SQL

      # netblocks
      connection.execute <<~SQL
        CREATE TABLE IF NOT EXISTS netblocks(
          range_start INTEGER,
          range_end INTEGER,
          geoname_id INTEGER
        )
      SQL
    end
  end
end
