# frozen_string_literal: true

require 'redis'
require 'fileutils'
require 'digest'
require 'openssl'
require 'base64'
require 'yaml'
require 'json'

module Lall
  class CacheManager
    DEFAULT_TTL = 3600 # 1 hour
    DEFAULT_CACHE_DIR = '~/.lall/cache'
    DEFAULT_SECRET_KEY_FILE = '~/.lall/secret.key'

    def initialize(options = {})
      @redis_url = options[:redis_url] || ENV['REDIS_URL']
      @cache_dir = expand_path(options[:cache_dir] || ENV['LALL_CACHE_DIR'] || 
                               cache_config['directory'] || DEFAULT_CACHE_DIR)
      @ttl = options[:ttl] || ENV['LALL_CACHE_TTL']&.to_i || 
             cache_config['ttl'] || DEFAULT_TTL
      @enabled = options.key?(:enabled) ? options[:enabled] : 
                 ENV['LALL_CACHE_ENABLED']&.downcase != 'false' && 
                 (cache_config['enabled'] != false)
      @secret_key_file = expand_path(options[:secret_key_file] || 
                                     ENV['LALL_SECRET_KEY_FILE'] || 
                                     cache_config['secret_key_file'] || 
                                     DEFAULT_SECRET_KEY_FILE)

      setup_cache_backend
      setup_encryption
    end

    def get(key, is_secret: false)
      return nil unless @enabled

      cached_data = backend_get(cache_key(key))
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
          # Parse JSON if it was a hash/object
          begin
            value = JSON.parse(value) if value.is_a?(String) && value.start_with?('{', '[')
          rescue JSON::ParserError
            # If JSON parsing fails, return as string
          end
        end

        value
      rescue JSON::ParserError, OpenSSL::Cipher::CipherError => e
        # If we can't parse or decrypt, treat as cache miss
        delete(key)
        nil
      end
    end

    def set(key, value, is_secret: false)
      return false unless @enabled

      data = {
        'value' => is_secret ? encrypt(value.to_json) : value,
        'encrypted' => is_secret,
        'created_at' => Time.now.to_i,
        'expires_at' => Time.now.to_i + @ttl
      }

      backend_set(cache_key(key), JSON.generate(data))
    end

    def delete(key)
      return false unless @enabled
      backend_delete(cache_key(key))
    end

    def clear
      return false unless @enabled
      
      if @redis
        @redis.flushdb
      else
        FileUtils.rm_rf(@cache_dir)
        FileUtils.mkdir_p(@cache_dir)
      end
      true
    end

    def enabled?
      @enabled
    end

    def stats
      {
        backend: @redis ? 'redis' : 'disk',
        enabled: @enabled,
        ttl: @ttl,
        cache_dir: @redis ? nil : @cache_dir,
        redis_url: @redis ? @redis_url&.gsub(/:\/\/.*@/, '://***@') : nil
      }
    end

    private

    def cache_config
      @cache_config ||= begin
        if defined?(SETTINGS) && SETTINGS['cache']
          SETTINGS['cache']
        else
          {}
        end
      end
    end

    def expand_path(path)
      File.expand_path(path.to_s)
    end

    def setup_cache_backend
      if @redis_url
        begin
          @redis = Redis.new(url: @redis_url)
          @redis.ping # Test connection
        rescue Redis::CannotConnectError, Redis::ConnectionError => e
          warn "Warning: Could not connect to Redis (#{@redis_url}): #{e.message}"
          warn "Falling back to disk cache"
          @redis = nil
          setup_disk_cache
        end
      else
        setup_disk_cache
      end
    end

    def setup_disk_cache
      FileUtils.mkdir_p(@cache_dir) unless File.exist?(@cache_dir)
    end

    def setup_encryption
      if File.exist?(@secret_key_file)
        @secret_key = File.read(@secret_key_file)
      else
        # Generate a new secret key
        @secret_key = OpenSSL::Random.random_bytes(32)
        FileUtils.mkdir_p(File.dirname(@secret_key_file))
        File.write(@secret_key_file, @secret_key)
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
      encrypted = data[28..-1]

      cipher = OpenSSL::Cipher.new('AES-256-GCM')
      cipher.decrypt
      cipher.key = @secret_key
      cipher.iv = iv
      cipher.auth_tag = auth_tag
      
      cipher.update(encrypted) + cipher.final
    end

    def cache_key(key)
      # Create a consistent cache key using SHA256
      Digest::SHA256.hexdigest("lall:#{key}")
    end

    def backend_get(key)
      if @redis
        @redis.get(key)
      else
        cache_file = File.join(@cache_dir, key)
        File.exist?(cache_file) ? File.read(cache_file) : nil
      end
    end

    def backend_set(key, value)
      if @redis
        @redis.set(key, value)
      else
        cache_file = File.join(@cache_dir, key)
        File.write(cache_file, value)
      end
      true
    end

    def backend_delete(key)
      if @redis
        @redis.del(key)
      else
        cache_file = File.join(@cache_dir, key)
        File.delete(cache_file) if File.exist?(cache_file)
      end
      true
    end
  end
end
