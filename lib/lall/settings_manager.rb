# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Lall
  # Manages settings resolution with priority order:
  # 1. Passed arguments (CLI options)
  # 2. Environment variables
  # 3. User settings (~/.lall/settings.yml)
  # 4. Gem default settings (config/settings.yml)
  class SettingsManager # rubocop:disable Metrics/ClassLength
    USER_SETTINGS_PATH = File.expand_path('~/.lall/settings.yml')
    GEM_SETTINGS_PATH = File.expand_path('../../config/settings.yml', __dir__)

    # Environment variable mappings for settings
    ENV_VAR_MAPPINGS = {
      'cache.ttl' => 'LALL_CACHE_TTL',
      'cache.directory' => 'LALL_CACHE_DIR',
      'cache.prefix' => 'LALL_CACHE_PREFIX',
      'cache.enabled' => 'LALL_CACHE_ENABLED',
      'cache.secret_key_file' => 'LALL_SECRET_KEY_FILE',
      'redis_url' => 'REDIS_URL',
      'debug' => 'LALL_DEBUG',
      'truncate' => 'LALL_TRUNCATE',
      'expose' => 'LALL_EXPOSE'
    }.freeze

    # Thread-safe singleton instance management
    @instance = nil
    @instance_mutex = Mutex.new

    class << self
      # Get or create singleton instance
      def instance(cli_options = {})
        return @instance if @instance && cli_options.empty?

        @instance_mutex.synchronize do
          @instance = new(cli_options) if @instance.nil? || !cli_options.empty?
          @instance
        end
      end

      # Clear singleton instance (mainly for testing)
      def reset!
        @instance_mutex.synchronize do
          @instance = nil
        end
      end
    end

    def initialize(cli_options = {})
      @cli_options = cli_options
      @user_settings = load_user_settings
      @gem_settings = load_gem_settings
    end

    # Get a setting value using the priority resolution
    # Supports dot notation for nested settings (e.g., 'cache.ttl')
    def get(setting_key, default_value = nil)
      # 1. Check CLI options first
      cli_value = get_from_cli(setting_key)
      return cli_value unless cli_value.nil?

      # 2. Check environment variables
      env_value = get_from_env(setting_key)
      return env_value unless env_value.nil?

      # 3. Check user settings file
      user_value = get_from_user_settings(setting_key)
      return user_value unless user_value.nil?

      # 4. Check gem default settings
      gem_value = get_from_gem_settings(setting_key)
      return gem_value unless gem_value.nil?

      # 5. Return provided default
      default_value
    end

    # Get all cache-related settings as a hash
    def cache_settings
      {
        ttl: get('cache.ttl', 3600).to_i,
        directory: File.expand_path(get('cache.directory', '~/.lall/cache').to_s),
        prefix: get('cache.prefix', 'lall-cache').to_s,
        enabled: parse_boolean(get('cache.enabled', true)),
        secret_key_file: File.expand_path(get('cache.secret_key_file', '~/.lall/secret.key').to_s),
        redis_url: get('redis_url')
      }
    end

    # Get all CLI-related settings as a hash
    def cli_settings
      {
        debug: parse_boolean(get('debug', false)),
        truncate: get('truncate', 40).to_i,
        expose: parse_boolean(get('expose', false)),
        insensitive: parse_boolean(get('insensitive', false)),
        path_also: parse_boolean(get('path_also', false)),
        pivot: parse_boolean(get('pivot', false))
      }
    end

    # Get all output formatting settings as a hash
    def output_settings
      {
        secret_placeholder: get('output.secret_placeholder', '{SECRET}').to_s
      }
    end

    # Get environment groups
    def groups
      get('groups', {})
    end

    # Create default user settings file if it doesn't exist
    def ensure_user_settings_exist
      return if File.exist?(USER_SETTINGS_PATH)

      user_dir = File.dirname(USER_SETTINGS_PATH)
      FileUtils.mkdir_p(user_dir)

      default_user_settings = build_default_user_settings
      # Convert to YAML with comments
      yaml_content = generate_yaml_with_comments(default_user_settings)
      File.write(USER_SETTINGS_PATH, yaml_content)
    end

    # Display the current settings resolution for debugging
    def debug_settings(setting_key = nil)
      if setting_key
        debug_single_setting(setting_key)
      else
        debug_all_settings
      end
    end

    private

    def build_default_user_settings # rubocop:disable Metrics/MethodLength
      {
        '# Lall Personal Settings' => nil,
        '# This file allows you to customize default behavior for the lall CLI tool.' => nil,
        '# Settings here will override gem defaults but can be overridden by ' \
        'environment variables or CLI options.' => nil,
        '# For more information, see: https://github.com/egrif/lall#settings-priority-resolution' => nil,
        '' => nil,
        'cache' => {
          '# Cache TTL in seconds (default: 3600 = 1 hour)' => nil,
          'ttl' => 3600,
          '# Cache directory path (default: ~/.lall/cache)' => nil,
          'directory' => '~/.lall/cache',
          '# Cache key prefix (default: lall-cache)' => nil,
          'prefix' => 'lall-cache',
          '# Enable/disable caching by default (default: true)' => nil,
          'enabled' => true,
          '# Secret key file for encryption (default: ~/.lall/secret.key)' => nil,
          'secret_key_file' => '~/.lall/secret.key'
        },
        'output' => {
          '# Default truncation length (default: 40)' => nil,
          'truncate' => 40,
          '# Enable debug output by default (default: false)' => nil,
          'debug' => false,
          '# Expose secrets by default (default: false, use with caution!)' => nil,
          'expose' => false,
          '# Case-insensitive search by default (default: false)' => nil,
          'insensitive' => false,
          '# Include paths in output by default (default: false)' => nil,
          'path_also' => false,
          '# Use pivot table format by default (default: false)' => nil,
          'pivot' => false
        }
      }
    end

    def load_user_settings
      return {} unless File.exist?(USER_SETTINGS_PATH)

      YAML.load_file(USER_SETTINGS_PATH) || {}
    rescue StandardError => e
      warn "Warning: Could not load user settings from #{USER_SETTINGS_PATH}: #{e.message}"
      {}
    end

    def load_gem_settings
      return {} unless File.exist?(GEM_SETTINGS_PATH)

      YAML.load_file(GEM_SETTINGS_PATH) || {}
    rescue StandardError => e
      warn "Warning: Could not load gem settings from #{GEM_SETTINGS_PATH}: #{e.message}"
      {}
    end

    def get_from_cli(setting_key)
      # Convert dot notation to symbol lookup in CLI options
      key_parts = setting_key.split('.')

      if key_parts.length == 1
        # Simple key like 'debug', 'truncate'
        key_sym = key_parts[0].to_sym
        @cli_options[key_sym]
      elsif key_parts.length == 2 && key_parts[0] == 'cache'
        # Cache-specific keys like 'cache.ttl' -> :cache_ttl
        # Special case: cache.directory -> :cache_dir (CLI uses cache_dir not cache_directory)
        if key_parts[1] == 'directory'
          @cli_options[:cache_dir]
        else
          cache_key = :"cache_#{key_parts[1]}"
          @cli_options[cache_key]
        end
      end
    end

    def get_from_env(setting_key)
      env_var = ENV_VAR_MAPPINGS[setting_key]
      return nil unless env_var

      value = ENV.fetch(env_var, nil)
      return nil if value.nil?

      # Convert string values to appropriate types
      case env_var
      when 'LALL_CACHE_TTL', 'LALL_TRUNCATE'
        value.to_i
      when 'LALL_CACHE_ENABLED', 'LALL_DEBUG', 'LALL_EXPOSE'
        parse_boolean(value)
      else
        value
      end
    end

    def get_from_user_settings(setting_key)
      # Try direct key first, then try nested under 'output' for CLI settings
      value = get_nested_value(@user_settings, setting_key.split('.'))
      return value unless value.nil?

      # For settings like 'debug', 'truncate', etc., also try under 'output'
      if setting_key.split('.').length == 1 && %w[debug truncate expose insensitive path_also
                                                  pivot].include?(setting_key)
        get_nested_value(@user_settings, ['output', setting_key])
      end
    end

    def get_from_gem_settings(setting_key)
      get_nested_value(@gem_settings, setting_key.split('.'))
    end

    def get_nested_value(hash, key_parts)
      key_parts.reduce(hash) do |current_hash, key|
        return nil unless current_hash.is_a?(Hash)

        current_hash[key] || current_hash[key.to_sym]
      end
    end

    def parse_boolean(value)
      case value
      when true, false
        value
      when String
        %w[true yes 1 on].include?(value.downcase)
      when Integer
        value != 0
      else
        false
      end
    end

    def debug_single_setting(setting_key)
      puts "Settings resolution for '#{setting_key}':"
      puts "  1. CLI argument: #{get_from_cli(setting_key) || 'not set'}"
      puts "  2. Environment:  #{get_from_env(setting_key) || 'not set'}"
      puts "  3. User config:  #{get_from_user_settings(setting_key) || 'not set'}"
      puts "  4. Gem default:  #{get_from_gem_settings(setting_key) || 'not set'}"
      puts "  → Final value:   #{get(setting_key) || 'nil'}"
    end

    def debug_all_settings
      puts 'Current settings resolution:'
      puts "\nCache settings:"
      cache_settings.each { |k, v| puts "  #{k}: #{v}" }
      puts "\nCLI settings:"
      cli_settings.each { |k, v| puts "  #{k}: #{v}" }
      puts "\nEnvironment groups: #{groups.keys.join(', ')}"
    end

    # Generate YAML content with inline comments
    def generate_yaml_with_comments(hash)
      lines = []

      hash.each do |key, value|
        if key.start_with?('#') || key.empty?
          # Add comment lines
          lines << (key.empty? ? '' : key)
        elsif value.nil?
          # Skip nil values (used for spacing and comments)
          next
        elsif value.is_a?(Hash)
          lines << "#{key}:"
          value.each do |subkey, subvalue|
            if subkey.start_with?('#')
              lines << "  #{subkey}"
            elsif subvalue.nil?
              next
            else
              lines << "  #{subkey}: #{subvalue.inspect}"
            end
          end
          lines << '' # Add blank line after each section
        else
          lines << "#{key}: #{value.inspect}"
        end
      end

      lines.join("\n")
    end
  end
end
