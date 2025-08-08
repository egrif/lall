# frozen_string_literal: true

module Lotus
  # Base class for Lotus entities (Environment and Group)
  # Provides common functionality for data fetching and region/space logic
  class Entity
    attr_reader :name, :data, :application, :space, :region, :secrets
    attr_accessor :parent_entity

    def initialize(name, space: nil, region: nil, application: 'greenhouse', parent: nil)
      @name = name
      @space = space
      @region = region
      @application = application
      @data = nil # Will be loaded later via fetch method
      @secrets = [] # Will be populated after data is loaded
      @parent_entity = parent
    end

    def fetch
      return @data if @data # Already loaded

      # Delegate to Lotus::Runner for fetching and caching
      require_relative 'runner'
      @data = Lotus::Runner.fetch(self)

      # Instantiate secret objects after data is loaded
      unless @data.nil? || instance_of?(::Lotus::Secret)
        require_relative 'secret' # Ensure Secret class is loaded
        instantiate_secrets
      end

      @data
    end

    def fetch_secrets(pattern = '*')
      unless %w[environment group].include?(lotus_type)
        raise NoMethodError,
              'undefined method `fetch_secrets`'
      end

      # Find matching secret keys from both environment and group secrets
      matching_keys = find_matching_secret_keys(pattern)

      return [] if matching_keys.empty?

      # Create Secret instances for each matching key
      secret_entities = matching_keys.map do |key_info|
        require_relative 'secret'
        Lotus::Secret.new(
          key_info[:key],
          space: space,
          region: region,
          application: @application,
          parent: key_info[:source_entity]
        )
      end

      # Fetch all secrets in parallel using Runner
      require_relative 'runner'
      Lotus::Runner.fetch_all(secret_entities)

      # Store secrets and return them
      @secrets = secret_entities
      secret_entities
    end

    def clear_cache
      require_relative '../lall/cache_manager'
      Lall::CacheManager.instance&.purge_entity(self)
      @data = nil
      @secrets = []
    end

    # Abstract methods to be implemented by subclasses
    def lotus_cmd
      raise NotImplementedError, 'Subclasses must implement lotus_cmd'
    end

    def lotus_parse(raw_data)
      raise NotImplementedError, 'Subclasses must implement lotus_parse'
    end

    def lotus_type
      self.class.name.split('::').last.downcase
    end

    def cache_key
      "#{cache_key_type}:#{name}:#{space}:#{region}:#{application}"
    end

    def cache_key_type
      self.class.name.split('::').last.downcase
    end

    private

    # Instantiate Secret objects for each secret key in the data
    def instantiate_secrets
      unless %w[environment group].include?(lotus_type)
        raise NoMethodError,
              'undefined method `instantiate_secrets`'
      end

      @secrets = []
      secret_keys = Array(@data.dig('secrets', 'keys'))

      secret_keys.each do |secret_key|
        secret = create_secret(secret_key)
        @secrets << secret
      end
    end

    def create_secret(secret_key)
      unless %w[environment group].include?(lotus_type)
        raise NoMethodError,
              'undefined method `create_secret`'
      end

      require_relative 'secret'
      Lotus::Secret.new(
        secret_key,
        space: space,
        region: region,
        application: application,
        parent: self
      )
    end
  end
end
