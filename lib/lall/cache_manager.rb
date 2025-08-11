# frozen_string_literal: true

require 'redis'
require 'moneta'
require 'fileutils'
require 'openssl'
require 'base64'
require 'yaml'
require 'json'
require 'cgi'

module Lall
  # CacheManager handles Redis and Moneta-based caching with encryption support
  # rubocop:disable Metrics/ClassLength
  class CacheManager
    DEFAULT_TTL = 3600 # 1 hour
    DEFAULT_CACHE_DIR = '~/.lall/cache'
    DEFAULT_SECRET_KEY_FILE = '~/.lall/secret.key'
    DEFAULT_CACHE_PREFIX = 'lall-cache'

    # Thread-safe singleton instance management
    @instance = nil
    @instance_mutex = Mutex.new

    class << self
      # Get or create singleton instance
      def instance(options = {})
        @instance_mutex.synchronize do
          @instance = new(options) if @instance.nil? || !options.empty?
          @instance
        end
      end

      # Reset instance (primarily for testing)
      def reset!
        @instance_mutex.synchronize do
          @instance = nil
        end
      end
    end
    # rubocop:disable Metrics/AbcSize
    def initialize(options = {})
      @redis_url = options[:redis_url] || ENV.fetch('REDIS_URL', nil)
      @cache_dir = expand_path(options[:cache_dir] || ENV['LALL_CACHE_DIR'] ||
                               cache_config['directory'] || DEFAULT_CACHE_DIR)
      @cache_prefix = options[:cache_prefix] || ENV['LALL_CACHE_PREFIX'] ||
                      cache_config['prefix'] || DEFAULT_CACHE_PREFIX
      @ttl = options[:ttl] || ENV['LALL_CACHE_TTL']&.to_i ||
             cache_config['ttl'] || DEFAULT_TTL
      @enabled = if options.key?(:enabled)
                   options[:enabled]
                 else
                   ENV['LALL_CACHE_ENABLED']&.downcase != 'false' &&
                     (cache_config['enabled'] != false)
                 end
      @secret_key_file = expand_path(options[:secret_key_file] ||
                                     ENV['LALL_SECRET_KEY_FILE'] ||
                                     cache_config['secret_key_file'] ||
                                     DEFAULT_SECRET_KEY_FILE)

      setup_cache_backend
      setup_encryption
    end
    # rubocop:enable Metrics/AbcSize

    def get(key)
      return nil unless @enabled

      cached_data = @cache_store.load(cache_key(key))
      return nil unless cached_data

      begin
        parsed_data = JSON.parse(cached_data)

        # Check expiration
        if Time.now.to_i > parsed_data['expires_at']
          delete(key)
          return nil
        end

        value = parsed_data['value']

        # Decrypt if it was stored as encrypted
        if parsed_data['encrypted']
          value = decrypt(value)
          # Parse JSON since encrypted values are always JSON-encoded
          begin
            value = JSON.parse(value)
          rescue JSON::ParserError
            # If JSON parsing fails, return as string
          end
        end

        value
      rescue JSON::ParserError, OpenSSL::Cipher::CipherError
        # If we can't parse or decrypt, treat as cache miss
        delete(key)
        nil
      end
    end

    def set(key, value, is_secret: false) # rubocop:disable Naming/PredicateMethod
      return false unless @enabled

      data = {
        'value' => is_secret ? encrypt(value.to_json) : value,
        'encrypted' => is_secret,
        'prefix' => @cache_prefix,
        'created_at' => Time.now.to_i,
        'expires_at' => Time.now.to_i + @ttl
      }

      @cache_store.store(cache_key(key), JSON.generate(data))
      true
    end

    def delete(key) # rubocop:disable Naming/PredicateMethod
      return false unless @enabled

      @cache_store.delete(cache_key(key))
      true
    end

    # Generic entity cache operations using cache_key
    def get_entity_data(entity)
      return nil unless @enabled

      get(entity.cache_key)
    end

    def set_entity_data(entity, data, is_secret: false)
      return false unless @enabled

      set(entity.cache_key, data, is_secret: is_secret)
    end

    # Purge all cache entries related to a specific entity (Environment or Group)
    def purge_entity(entity) # rubocop:disable Naming/PredicateMethod
      return false unless @enabled

      # Check if entity supports cache_key method
      unless entity.respond_to?(:cache_key)
        raise ArgumentError, "Unsupported entity type: #{entity.class}. Expected Lotus::Environment or Lotus::Group"
      end

      # Use unified cache key approach
      delete(entity.cache_key)

      # For environments and groups, also purge any associated secrets
      case entity
      when Lotus::Environment
        purge_environment_secret_entries(entity)
      when Lotus::Group
        purge_group_secret_entries(entity)
      end

      true
    end

    def clear_cache # rubocop:disable Naming/PredicateMethod
      return false unless @enabled

      clear_prefixed_keys
      true
    end

    def enabled?
      @enabled
    end

    def stats
      basic_stats = {
        backend: backend_name,
        enabled: @enabled,
        ttl: @ttl,
        cache_prefix: @cache_prefix,
        cache_dir: @backend_type == :redis ? nil : @cache_dir,
        redis_url: @backend_type == :redis ? @redis_url&.gsub(%r{://.*@}, '://***@') : nil,
        cache_size: calculate_cache_size
      }

      # Add entity counts
      basic_stats[:entity_counts] = calculate_entity_counts

      basic_stats
    end

    private

    # Purge secret cache entries for a specific environment using pattern matching
    def purge_environment_secret_entries(environment)
      purge_entity_secret_keys('ENV-SECRET', environment.name, environment.space, environment.region)
    end

    # Purge secret cache entries for a specific group using pattern matching
    def purge_group_secret_entries(group)
      purge_entity_secret_keys('GROUP-SECRET', group.name, group.space, group.region)
    end

    # Purge secret cache keys for an entity (environment or group)
    def purge_entity_secret_keys(secret_type, entity_name, space, region)
      # Build pattern to match secret keys for this entity
      # Secret keys follow format: PREFIX.SECRET-TYPE.ENTITY.SPACE.REGION.SECRET_KEY
      pattern_prefix = cache_key("#{secret_type}.#{entity_name}.#{space}.#{region}")

      case @backend_type
      when :redis
        # Use Redis pattern matching to find and delete keys
        redis_pattern = "#{pattern_prefix}.*"
        keys = @cache_store.instance_variable_get(:@redis).keys(redis_pattern)
        @cache_store.instance_variable_get(:@redis).del(keys) unless keys.empty?
      when :moneta
        # For Moneta, iterate through cache directory and match patterns
        purge_moneta_pattern_keys(pattern_prefix)
      end
    end

    # Purge Moneta keys that match a specific pattern prefix
    def purge_moneta_pattern_keys(pattern_prefix)
      return unless File.directory?(@cache_dir)

      Dir.glob(File.join(@cache_dir, '*')).each do |file_path|
        next unless File.file?(file_path)

        begin
          # Get the key from the filename (URL decode it)
          filename = File.basename(file_path)
          key = CGI.unescape(filename)

          # Check if this key matches our pattern
          @cache_store.delete(key) if key.start_with?(pattern_prefix)
        rescue StandardError
          # If we can't process the file, skip it
          next
        end
      end
    end

    def cache_config
      @cache_config ||= if defined?(SETTINGS) && SETTINGS['cache']
                          SETTINGS['cache']
                        else
                          {}
                        end
    end

    def expand_path(path)
      File.expand_path(path.to_s)
    end

    def setup_cache_backend
      if @redis_url
        setup_redis_backend
      else
        setup_moneta_backend
      end
    end

    def setup_redis_backend
      redis_client = Redis.new(url: @redis_url)
      redis_client.ping # Test connection
      @cache_store = Moneta.new(:Redis, redis: redis_client)
      @backend_type = :redis
    rescue Redis::CannotConnectError, Redis::ConnectionError
      setup_moneta_backend
    end

    def setup_moneta_backend
      FileUtils.mkdir_p(@cache_dir)
      # Use Moneta's File adapter for reliable disk-based caching
      @cache_store = Moneta.new(:File, dir: @cache_dir)
      @backend_type = :moneta
    end

    def backend_name
      @backend_type == :redis ? 'redis' : 'moneta'
    end

    def setup_encryption
      if File.exist?(@secret_key_file)
        @secret_key = File.binread(@secret_key_file)
      else
        # Generate a new secret key
        @secret_key = OpenSSL::Random.random_bytes(32)
        FileUtils.mkdir_p(File.dirname(@secret_key_file))
        File.binwrite(@secret_key_file, @secret_key)
        File.chmod(0o600, @secret_key_file) # Secure permissions
      end
    end

    def encrypt(data)
      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.encrypt
      cipher.key = @secret_key
      iv = cipher.random_iv # This will be 12 bytes for GCM
      encrypted = cipher.update(data.to_s) + cipher.final
      auth_tag = cipher.auth_tag

      # Combine IV, auth tag, and encrypted data
      Base64.strict_encode64(iv + auth_tag + encrypted)
    end

    def decrypt(encrypted_data)
      data = Base64.strict_decode64(encrypted_data)

      # Extract IV (12 bytes), auth tag (16 bytes), and encrypted data
      iv = data[0, 12]
      auth_tag = data[12, 16]
      encrypted = data[28..]

      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.decrypt
      cipher.key = @secret_key
      cipher.iv = iv
      cipher.auth_tag = auth_tag

      cipher.update(encrypted) + cipher.final
    end

    def cache_key(key)
      # Use human-readable cache keys with prefix (no hashing)
      "#{@cache_prefix}.#{key}"
    end

    def clear_prefixed_keys
      case @backend_type
      when :redis
        # For Redis, use pattern matching to delete only keys with our prefix
        pattern = "#{@cache_prefix}.*"
        keys = @cache_store.instance_variable_get(:@redis).keys(pattern)
        @cache_store.instance_variable_get(:@redis).del(keys) unless keys.empty?
      when :moneta
        # For Moneta file backend, iterate through files and check each one
        clear_prefixed_moneta_keys
      end
    end

    def clear_prefixed_moneta_keys
      return unless File.directory?(@cache_dir)

      Dir.glob(File.join(@cache_dir, '*')).each do |file_path|
        next unless File.file?(file_path)

        begin
          # Get the key from the filename (URL decode it)
          filename = File.basename(file_path)
          key = CGI.unescape(filename)

          # Check if this key starts with our prefix
          @cache_store.delete(key) if key.start_with?("#{@cache_prefix}.")
        rescue StandardError
          # If we can't process the file, skip it
          next
        end
      end
    end

    def calculate_cache_size
      case @backend_type
      when :redis
        calculate_redis_cache_size
      when :moneta
        calculate_moneta_cache_size
      else
        { total_keys: 0, prefixed_keys: 0, total_size_bytes: 0 }
      end
    end

    def calculate_redis_cache_size
      return { total_keys: 0, prefixed_keys: 0, total_size_bytes: 0 } unless @redis_url

      begin
        redis_client = @cache_store.instance_variable_get(:@redis)
        pattern = "#{@cache_prefix}.*"
        prefixed_keys = redis_client.keys(pattern)

        total_size = 0
        prefixed_keys.each do |key|
          total_size += redis_client.memory('usage', key) || 0
        rescue Redis::CommandError
          # If MEMORY USAGE is not supported, estimate based on string length
          total_size += redis_client.get(key)&.bytesize || 0
        end

        {
          total_keys: redis_client.dbsize,
          prefixed_keys: prefixed_keys.count,
          total_size_bytes: total_size
        }
      rescue StandardError
        { total_keys: 0, prefixed_keys: 0, total_size_bytes: 0 }
      end
    end

    def calculate_moneta_cache_size
      return { total_keys: 0, prefixed_keys: 0, total_size_bytes: 0 } unless File.directory?(@cache_dir)

      total_files = 0
      prefixed_files = 0
      total_size = 0

      Dir.glob(File.join(@cache_dir, '*')).each do |file_path|
        next unless File.file?(file_path)

        total_files += 1
        file_size = File.size(file_path)
        total_size += file_size

        begin
          filename = File.basename(file_path)
          key = CGI.unescape(filename)
          prefixed_files += 1 if key.start_with?("#{@cache_prefix}.")
        rescue StandardError
          # Skip files we can't decode
          next
        end
      end

      {
        total_keys: total_files,
        prefixed_keys: prefixed_files,
        total_size_bytes: total_size
      }
    end

    def calculate_entity_counts
      case @backend_type
      when :redis
        calculate_redis_entity_counts
      when :moneta
        calculate_moneta_entity_counts
      else
        { environments: 0, groups: 0, env_secrets: 0, group_secrets: 0 }
      end
    end

    def calculate_redis_entity_counts
      return { environments: 0, groups: 0, env_secrets: 0, group_secrets: 0 } unless @redis_url

      begin
        redis_client = @cache_store.instance_variable_get(:@redis)
        pattern = "#{@cache_prefix}.*"
        prefixed_keys = redis_client.keys(pattern)

        count_entities_from_keys(prefixed_keys)
      rescue StandardError
        { environments: 0, groups: 0, env_secrets: 0, group_secrets: 0 }
      end
    end

    def calculate_moneta_entity_counts
      return { environments: 0, groups: 0, env_secrets: 0, group_secrets: 0 } unless File.directory?(@cache_dir)

      keys = []
      Dir.glob(File.join(@cache_dir, '*')).each do |file_path|
        next unless File.file?(file_path)

        begin
          filename = File.basename(file_path)
          key = CGI.unescape(filename)
          keys << key if key.start_with?("#{@cache_prefix}.")
        rescue StandardError
          next
        end
      end

      count_entities_from_keys(keys)
    end

    def count_entities_from_keys(keys)
      environments = 0
      groups = 0
      env_secrets = 0
      group_secrets = 0

      keys.each do |key|
        # Remove cache prefix to get the actual key
        clean_key = key.sub(/^#{Regexp.escape(@cache_prefix)}\./, '')

        case clean_key
        when /^environment:/
          environments += 1
        when /^group:/
          groups += 1
        when /^environment_secret_/
          env_secrets += 1
        when /^group_secret_/
          group_secrets += 1
        end
      end

      {
        environments: environments,
        groups: groups,
        env_secrets: env_secrets,
        group_secrets: group_secrets
      }
    end
  end
  # rubocop:enable Metrics/ClassLength
end
