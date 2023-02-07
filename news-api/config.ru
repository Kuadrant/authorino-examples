# frozen_string_literal: true

require 'logger'
require 'json'
require 'securerandom'
require 'base64'
require 'forwardable'
require 'redis'

Object.include(Module.new do
  def try(method, *args)
    send(method, *args) if respond_to?(method)
  end
end)

Hash.include(Module.new do
  def symbolize_keys
    transform_keys{ |key| key.to_sym rescue key }
  end

  def reverse_merge(other_hash)
    other_hash.merge(self)
  end
end)

class MemoryStorage
  def initialize
    @news = {}
  end

  def list(category)
    @news[category]&.values || []
  end

  def add(category, article)
    @news[category] ||= {}
    @news[category][article.id] = article
  end

  def get(category, article_id)
    @news.dig(category, article_id)
  end

  def delete(category, article_id)
    @news[category]&.delete(article_id)
  end

  def exists?(article_id)
    @news.values.flat_map(&:keys).include?(article_id)
  end
end

class RedisStorage
  def initialize(redis_url)
    @storage = Redis.new(url: redis_url)
  end

  def list(category)
    @storage.hgetall(category).values.map(&JSON.method(:parse)).map(&Article.method(:new))
  end

  def add(category, article)
    @storage.hset(category, article.id, article.to_json)
    article
  end

  def get(category, article_id)
    article = @storage.hget(category, article_id)
    Article.new(JSON.parse(article)) if article
  end

  def delete(category, article_id)
    article = get(category, article_id)
    article if @storage.hdel(category, article_id) > 0
  end

  def exists?(article_id)
    @storage.scan(0).last.find { |category| @storage.hexists(category, article_id) }
  end
end

class Storage
  extend Forwardable
  def_delegators :@storage, :list, :add, :get, :delete, :exists?

  def initialize(config = {})
    @storage = RedisStorage.new(config[:redis_url]) if config[:redis_url]
    @storage ||= MemoryStorage.new
  end
end

ATTRIBUTES = %i[title body date author user_id].freeze

class Article < Struct.new(:id, *ATTRIBUTES, keyword_init: true)
  def self.create(**params)
    new(**params.merge(id: SecureRandom.uuid))
  end

  def to_json
    to_h.to_json
  end
end

class RackApp
  def initialize
    @storage = Storage.new(redis_url: ENV['REDIS_URL'])
    @logger = Logger.new(STDOUT)
    @logger.level = ENV['LOG_LEVEL'] || 'info'
  end

  attr_reader :storage, :logger

  def call(env)
    request = Rack::Request.new(env)

    request_method = request.request_method
    request_path = request.path
    request_query_string = request.query_string
    request_query_string = nil if request_query_string.empty?

    _, category, article_id = request_path.split('/')

    extra_headers = {}
    extra_headers.merge!('X-Ext-Auth-Data' => env[X_AUTH_DATA_HEADER]) if env[X_AUTH_DATA_HEADER]
    extra_headers.merge!('X-Ext-Auth-Wristband' => env[X_AUTH_WRISTBAND_HEADER]) if env[X_AUTH_WRISTBAND_HEADER]

    response = case request_method
    when 'GET'
      if article_id.to_s.empty?
      respond_with(storage.list(category).map(&:to_h), extra_headers: extra_headers)
    else
      respond_with(storage.get(category, article_id), extra_headers: extra_headers)
      end
    when 'POST'
      params = JSON.parse(request.body.read).symbolize_keys.slice(*ATTRIBUTES)
      author, user_id = parse_auth_data(env)
      params.merge!(date: Time.now, author: author, user_id: user_id)

      article = Article.new(id: article_id, **params) if article_id
      article ||= loop do # prevents duplicate article id
        article = Article.create(params)
        break article unless storage.exists?(article.id)
      end

      storage.exists?(article.id) ? render(:unprocessable_entity) : respond_with(storage.add(category, article), extra_headers: extra_headers)
    when 'DELETE'
      respond_with(storage.delete(category, article_id), extra_headers: extra_headers)
    else
      render :not_found
    end
  rescue StandardError => e
    response = render(e.try(:status) || :server_error, body: e.message)
  ensure
    logger.info "#{request_method} #{[request_path, request_query_string].compact.join('?')} => #{response.first}"
  end

  protected

  X_AUTH_DATA_HEADER = 'HTTP_X_EXT_AUTH_DATA'
  X_AUTH_WRISTBAND_HEADER = 'HTTP_X_EXT_AUTH_WRISTBAND'

  def json_response(body)
    [{'Content-Type' => 'application/json'}, [body.to_json]]
  end

  def render_ok(body)
    [200, *json_response(body)]
  end

  def render_not_found(*)
    [404, *json_response(error: 'Not found')]
  end

  def render_unprocessable_entity(*)
    [422, *json_response(error: 'Unprocessable Entity')]
  end

  def render_server_error(message)
    [500, *json_response(error: message)]
  end

  def render(status, body: nil)
    send("render_#{status}", body)
  end

  def respond_with(object, extra_headers: {})
    return render(:not_found) unless object
    status, headers, body = render(:ok, body: object)
    [status, headers.merge(extra_headers), body]
  end

  def parse_auth_data(env)
    x_auth_data = env[X_AUTH_DATA_HEADER]
    x_auth_data = nil if x_auth_data == 'null'

    if x_auth_data
      auth_data = JSON.parse(x_auth_data)
      return auth_data.values_at('author', 'user_id')
    end

    wristband_token = env[X_AUTH_WRISTBAND_HEADER]
    wristband_token = nil if wristband_token == 'null'

    if wristband_token
      wristband_payload = JSON.parse(Base64.decode64(wristband_token.split('.')[1]))
      return wristband_payload.values_at('name', 'sub')
    end

    ['Unknown', nil]
  rescue JSON::ParserError => e
    logger.debug "Failed to parse auth data: #{e}"
    ['Unknown', nil]
  end
end

run(RackApp.new)
