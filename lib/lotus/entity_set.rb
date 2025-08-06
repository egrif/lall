# frozen_string_literal: true

require_relative 'environment'
require_relative 'group'

module Lotus
  class EntitySet
    attr_reader :entities, :settings

    def initialize(entities_or_settings = [], settings = nil)
      # If first parameter is a SettingsManager, create entities from it
      if entities_or_settings.respond_to?(:groups)
        @settings = entities_or_settings
        @entities = create_environments_from_settings(@settings)
      else
        # Traditional initialization with entities array
        @entities = entities_or_settings
        @settings = settings
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

    def find_by_id(id)
      @entities.find { |entity| entity.id == id }
    end

    def find_by_name(name)
      @entities.find { |entity| entity.name == name }
    end

    def all
      @entities
    end

    def fetch_all
      # First, instantiate and fetch all environments in parallel
      require_relative 'runner'
      environments = instantiate_all_environments
      Lotus::Runner.fetch_all(environments)

      # Then, get group names from the fetched environments and instantiate groups
      groups = instantiate_groups_from_environments(environments)
      Lotus::Runner.fetch_all(groups) unless groups.empty?

      # Store both environments and groups in entities
      @entities = environments + groups

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

    def fetch
      # First, fetch all environments in parallel
      require_relative 'runner'
      Lotus::Runner.fetch_all(@entities)

      # Then, create and fetch all groups that these environments belong to
      groups = create_groups_from_environment_memberships
      Lotus::Runner.fetch_all(groups) unless groups.empty?

      # Return self for method chaining
      self
    end

    # Get all unique group names that environments belong to
    def group_names
      return [] unless @settings

      # Find which groups contain our environments
      environment_names = @entities.map(&:name)
      group_names = []

      @settings.groups.each do |group_name, group_environments|
        # Check if any of our environments are in this group
        group_names << group_name if group_environments.any? { |env_name| environment_names.include?(env_name) }
      end

      group_names.uniq
    end

    private

    def instantiate_all_environments
      return [] unless @settings

      environments = []
      target_environments = determine_target_environments(@settings)

      target_environments.each do |env_name|
        environment = Lotus::Environment.new(
          env_name,
          parent: self
        )
        environments << environment
      end

      environments
    end

    def instantiate_groups_from_environments(environments)
      return [] unless @settings

      # Get all unique group names from the fetched environments
      group_names = []
      environments.each do |env|
        # Only process environments that have loaded data
        next unless env.data

        group_name = env.data['group']
        group_names << group_name if group_name && !group_names.include?(group_name)
      end

      # Create Group instances
      groups = []
      group_names.each do |group_name|
        group = Lotus::Group.new(
          group_name,
          application: 'greenhouse',
          parent: self
        )
        groups << group
      end

      groups
    end

    def create_groups_from_environment_memberships
      return [] unless @settings

      groups = []
      unique_group_names = group_names

      unique_group_names.each do |group_name|
        # Create Group instance - groups inherit space/region from environment logic
        # For now, use default space/region (will be determined in Group's lotus_cmd)
        group = Lotus::Group.new(
          group_name,
          application: 'greenhouse',
          parent: self
        )
        groups << group
      end

      groups
    end

    def create_environments_from_settings(settings)
      environments = []
      cache_manager = initialize_cache_manager(settings)

      # Get the specific environments that should be created
      target_environments = determine_target_environments(settings)

      target_environments.each do |env_name|
        # Create Environment instance
        environment = Lotus::Environment.new(
          env_name,
          parent: self
        )

        # Set cache manager for backward compatibility with tests
        environment.instance_variable_set(:@cache_manager, cache_manager)

        environments << environment
      end

      environments
    end

    def determine_target_environments(settings)
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

    def initialize_cache_manager(settings)
      cache_settings = settings.cache_settings

      if cache_settings[:enabled]
        require_relative '../lall/cache_manager'
        Lall::CacheManager.instance(cache_settings)
      else
        # Return a null cache manager if caching is disabled
        require_relative '../lall/cli'
        LallCLI::NullCacheManager.new
      end
    end
  end
end
