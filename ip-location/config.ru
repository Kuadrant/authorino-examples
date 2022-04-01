# frozen_string_literal: true

require 'optparse'
require 'json'
require 'ipaddr'
require 'ip_location'

options = { db: ENV.fetch('DB_PATH', 'data.sqlite') }
options[:netblocks] = ENV['NETBLOCKS_IMPORT_PATH'] if ENV['NETBLOCKS_IMPORT_PATH']
options[:locations] = ENV['LOCATIONS_IMPORT_PATH'] if ENV['LOCATIONS_IMPORT_PATH']

class App
  def initialize(locator)
    @locator = locator
  end

  attr_reader :locator

  def call(env)
    request = Rack::Request.new(env)

    return respond(request, status: 404) if request.request_method != 'GET'

    ip = request.path.split('/')[1]
    ip ||= request.params['ip']
    ip ||= (env['HTTP_X_FORWARDED_FOR'] || '').split(',').first

    ip&.strip!

    return respond(request, status: 404) if !ip || ip.empty?

    return respond(request, status: 400) unless (IPAddr.new(ip) rescue nil)

    data = locator.call(ip)

    return respond(request, status: 404) unless data

    respond(request,
      status: 200,
      headers: { 'Content-Type' => 'application/json' },
      body: JSON.pretty_generate(data)
    )
  end

  def respond(request, status:, headers: {}, body: '')
    request_method = request.request_method
    request_path = request.path
    request_query_string = request.query_string
    request_query_string = nil if request_query_string.empty?
    request_status_line = "#{request_method} #{[request_path, request_query_string].compact.join('?')}"

    puts "[#{Time.now}] #{request_status_line} => #{status}"

    [status, headers, [body]]
  end
end

db = IpLocation::Database.new(options[:db])
%i[locations netblocks].each { |t| db.public_send("import_#{t}", options[t]) if options[t] }
locator = IpLocation::Locator.new(db)

run App.new(locator)
