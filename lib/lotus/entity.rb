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
      group_secret_keys = Array(@data.dig('group_secrets', 'keys'))
      all_secret_keys = secret_keys + group_secret_keys

      # Only instantiate secrets that match the search pattern
      search_context = Lotus::Runner.search_context
      search_pattern = search_context[:search_pattern]
      
      if search_pattern && !all_secret_keys.empty?
        # Filter secret keys based on search pattern
        matching_secret_keys = secret_keys.select do |secret_key|
          if search_context[:insensitive]
            secret_key.downcase.include?(search_pattern.downcase)
          else
            secret_key.include?(search_pattern)
          end
        end
        
        matching_group_secret_keys = group_secret_keys.select do |secret_key|
          if search_context[:insensitive]
            secret_key.downcase.include?(search_pattern.downcase)
          else
            secret_key.include?(search_pattern)
          end
        end
        
        # Create secrets for regular secret keys
        matching_secret_keys.each do |secret_key|
          secret = create_secret(secret_key)
          secret.fetch  # Fetch the secret data
          @secrets << secret
        end
        
        # Create group secrets for group secret keys
        matching_group_secret_keys.each do |secret_key|
          secret = create_group_secret(secret_key)
          secret.fetch  # Fetch the secret data
          @secrets << secret
        end
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

    def create_group_secret(secret_key)
      unless lotus_type == 'environment'
        raise NoMethodError,
              'undefined method `create_group_secret` - only available for environments'
      end

      # Group secrets need to be created with the group as parent, not the environment
      # First, get the group entity
      group_entity = Lotus::Group.new(
        group_name,
        space: space,
        region: region,
        application: application
      )

      require_relative 'secret'
      Lotus::Secret.new(
        secret_key,
        space: space,
        region: region,
        application: application,
        parent: group_entity
      )
    end
  end
end
