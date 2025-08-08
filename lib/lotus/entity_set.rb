# frozen_string_literal: true

require_relative 'environment'
require_relative 'group'

module Lotus
  # EntitySet manages collections of Lotus entities (Environments and Groups)
  # Provides parallel fetching, instantiation, and relationship management
  # rubocop:disable Metrics/ClassLength
  class EntitySet
    attr_reader :entities, :settings

    def initialize(entities_or_settings = nil, settings = nil)
      # Handle different calling patterns:
      # new() - empty initialization
      # new(settings) - settings only
      # new(entities, settings) - entities and settings

      if entities_or_settings.nil?
        # new() - empty initialization
        @entities = []
        @settings = nil
      elsif settings.nil?
        # new(settings) - first parameter is settings
        if entities_or_settings.respond_to?(:groups)
          @entities = []
          @settings = entities_or_settings
          @entities += instantiate_all_environments
        else
          # new(entities) - first parameter is entities array
          @entities = entities_or_settings
          @settings = nil
        end
      else
        # new(entities, settings) - both parameters provided
        @entities = entities_or_settings
        @settings = settings
        @entities += instantiate_all_environments if settings
      end
    end

    def add(entity)
      @entities << entity
      # Set parent reference for the entity
      entity.instance_variable_set(:@parent_entity, self)
    end

    def remove(entity)
      @entities.delete(entity)
      # Clear parent reference for the entity
      entity.instance_variable_set(:@parent_entity, nil)
    end

    def all
      @entities
    end

    def fetch_all(pattern = "*")
      # First, instantiate and fetch all environments in parallel
      require_relative 'runner'
      environments = @entities.select { |e| e.is_a?(Lotus::Environment) }
      environments = instantiate_all_environments if environments.empty?
      Lotus::Runner.fetch_all(environments)

      # Then, get group names from the fetched environments and instantiate groups
      groups = instantiate_groups_from_environments(environments)
      Lotus::Runner.fetch_all(groups) unless groups.empty?

      # Store both environments and groups in entities
      @entities = environments + groups

      fetch_secrets(pattern) if pattern && !pattern.empty?

      # Return self for method chaining
      self
    end

    # Get environments from the entity set
    def environments
      @entities.select { |entity| entity.is_a?(Lotus::Environment) }
    end

    # Get groups from the entity set
    def groups
      @entities.select { |entity| entity.is_a?(Lotus::Group) }
    end

    # def fetch
    #   # First, fetch all environments in parallel
    #   require_relative 'runner'
    #   Lotus::Runner.fetch_all(@entities)

    #   # Then, create and fetch all groups that these environments belong to
    #   environments = @entities.select { |e| e.is_a?(Lotus::Environment) }
    #   groups = instantiate_groups_from_environments(environments)
    #   Lotus::Runner.fetch_all(groups) unless groups.empty?

    #   # Return self for method chaining
    #   self
    # end

    # make sure values are known for all secrets that match the glob
    def fetch_secrets(pattern = '*')
      @entities.each do |entity|
        entity.fetch_secrets(pattern)
      end
    end

    def find_entity(type, name, space, region, application)
      # Find an entity by type, name, space, region, and application
      @entities.find do |entity|
        entity.lotus_type == type &&
          entity.name == name &&
          entity.space == space &&
          entity.region == region &&
          entity.application == application
      end
    end

    def find_equivalent_entity(entity, collection = nil)
      # Find an equivalent entity in the collection based on type, name, space, region, and application
      collection ||= @entities
      collection.find do |e|
        e.lotus_type == entity_type &&
          e.name == entity.name &&
          e.space == entity.space &&
          e.region == entity.region &&
          e.application == entity.application
      end
    end

    private

    def instantiate_all_environments
      return [] unless @settings

      # Initialize cache manager based on settings
      cache_manager = initialize_cache_manager

      environments = []
      target_environments = determine_target_environments(@settings)

      target_environments.each do |env_name|
        environment = Lotus::Environment.new(
          env_name,
          parent: self
        )
        # Set cache manager on environment
        environment.instance_variable_set(:@cache_manager, cache_manager)
        environments << environment
      end

      environments
    end

    def initialize_cache_manager
      return nil unless @settings.respond_to?(:cache_settings)

      cache_settings = @settings.cache_settings
      if cache_settings[:enabled]
        require_relative '../lall/cache_manager'
        Lall::CacheManager.new(cache_settings)
      else
        require_relative '../lall/null_cache_manager'
        Lall::NullCacheManager.new
      end
    rescue StandardError
      # Fallback to null cache manager if initialization fails
      require_relative '../lall/null_cache_manager'
      Lall::NullCacheManager.new
    end

    def instantiate_groups_from_environments(environments)
      # Get all unique group names from the fetched environments and derive their attributes
      groups = []
      environments.each do |env|
        # Only process environments that have loaded data
        next unless env.data

        group_name = env.group_name
        next unless group_name

        # Initialize group info if we haven't seen this group before
        next if find_entity('group', group_name, env.space, env.region, env.application)

        groups << create_group_from_environment(group_name, env)
      end

      groups
    end

    def create_group_from_environment(group_name, environment)
      Lotus::Group.new(
        group_name,
        space: environment.space,
        region: environment.region,
        application: environment.application,
        parent: self
      )
    end

    def determine_target_environments(settings)
      # Handle cases where settings is nil or not the expected type
      return [] unless settings.respond_to?(:groups)

      # Check if specific environments or group was requested in CLI options
      cli_options = settings.instance_variable_get(:@cli_options) || {}

      if cli_options[:group]
        # Get environments from the specified group
        settings.groups[cli_options[:group]] || []
      elsif cli_options[:env]
        # Get environments from comma-separated list
        cli_options[:env].split(',').map(&:strip)
      else
        # Fallback: get all environments from all groups (original behavior)
        all_environments = []
        settings.groups.each_value do |environment_names|
          environment_names.each do |env_name|
            # Skip duplicates - same environment might be in multiple groups
            next if all_environments.include?(env_name)

            all_environments << env_name
          end
        end
        all_environments
      end
    end

    # Check if all entities have their data loaded
    def entities_data_loaded?
      @entities.all?(&:data)
    end

    # Find matching secrets for a specific entity based on glob pattern
    def find_entity_matching_secrets(entity, pattern)
      matching_secrets = []

      # Convert glob pattern to regex (using same logic as Environment)
      regex_pattern = glob_to_regex(pattern)

      # Check if entity has secrets array (instantiated from Entity base class)
      return matching_secrets unless entity.secrets

      # Find matching secrets from the entity's secrets
      entity.secrets.each do |secret|
        matching_secrets << secret if secret.name.match?(regex_pattern)
      end

      matching_secrets
    end

    # Convert glob pattern to regex (same logic as in Environment)
    def glob_to_regex(pattern)
      # Convert shell glob pattern to regex
      # * matches any characters
      # ? matches any single character
      escaped = Regexp.escape(pattern)
      escaped.gsub!('\*', '.*')
      escaped.gsub!('\?', '.')
      /^#{escaped}$/i
    end
  end
  # rubocop:enable Metrics/ClassLength
end
