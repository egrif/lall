# frozen_string_literal: true

require_relative '../lall/cache_manager'

module Lotus
  class Group
    attr_reader :name, :data, :application

    def initialize(yaml_hash_or_name, application: 'greenhouse', cache_manager: nil)
      if yaml_hash_or_name.is_a?(Hash)
        # Legacy constructor with YAML data
        @data = yaml_hash_or_name
        @name = nil
        @application = application
        @cache_manager = cache_manager || Lall::CacheManager.instance
      else
        # New constructor with group name
        @name = yaml_hash_or_name
        @application = application
        @cache_manager = cache_manager || Lall::CacheManager.instance
        @data = nil # Will be loaded later via fetch method
      end
    end

    # Class method for creating group with specific parameters
    def self.from_args(group:, application: 'greenhouse', cache_manager: nil)
      new(group, application: application, cache_manager: cache_manager)
    end

    def configs
      raise NoMethodError, 'undefined method `configs` - requires data to be loaded first' if @data.nil?

      @data['configs'] || {}
    end

    def secrets
      raise NoMethodError, 'undefined method `secrets` - requires data to be loaded first' if @data.nil?

      Array(@data.dig('secrets', 'keys'))
    end

    def fetch
      return @data if @data # Already loaded

      # Try to get from cache first
      cached_data = @cache_manager&.get_group_data(@name, @application)
      if cached_data
        @data = cached_data
        return @data
      end

      # Cache miss - fetch from lotus
      fetch_from_lotus
    end

    private

    def fetch_from_lotus
      # Fetch group YAML data
      yaml_data = Lotus::Runner.fetch_group_yaml(nil, @name)
      return nil unless yaml_data

      @data = yaml_data

      # Cache the group data
      @cache_manager&.set_group_data(@name, @application, @data)

      @data
    end
  end
end
