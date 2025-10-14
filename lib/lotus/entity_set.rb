# frozen_string_literal: true

require_relative 'environment'
require_relative 'group'
require_relative '../lall/settings_manager'

module Lotus
  # EntitySet manages collections of Lotus entities (Environments and Groups)
  # Provides parallel fetching, instantiation, and relationship management
  class EntitySet
    attr_reader :entities, :settings

    def initialize(_entities = nil, settings = nil)
      @settings = settings || Lall::SettingsManager.instance
      @entities = instantiate_all_environments
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

    # rubocop:disable Metrics/AbcSize
    def fetch_all(pattern = nil)
      # Get pattern from settings if not provided
      pattern ||= search_pattern_from_settings

      # First, instantiate and fetch all environments in parallel
      require_relative 'runner'
      envs = environments
      envs = instantiate_all_environments if envs.empty?
      Lotus::Runner.fetch_all(environments)

      # Then, get group names from the fetched environments and instantiate groups
      grps = instantiate_groups_from_environments(environments)
      if @settings&.instance_variable_get(:@cli_options)&.dig(:debug)
        puts "DEBUG: Instantiated #{grps.size} groups from environments"
      end
      Lotus::Runner.fetch_all(grps) unless grps.empty?
      # Store both environments and groups in entities
      @entities = envs + grps

      @entities.each do |entity|
        # If a search pattern is provided, filter secrets for each entity
        secrets = entity.matched_secrets(pattern)
        if @settings&.instance_variable_get(:@cli_options)&.dig(:debug) && pattern
          puts "DEBUG: #{entity.lotus_type} #{entity.name} matched #{secrets.size} secrets with pattern '#{pattern}'"
        end
        Lotus::Runner.fetch_all(secrets) unless secrets.empty?
      end
      # Return self for method chaining
      self
    end
    # rubocop:enable Metrics/AbcSize

    # Get environments from the entity set
    def environments
      @entities.select { |entity| entity.lotus_type == 'environment' }
    end

    # Get groups from the entity set
    def groups
      @entities.select { |entity| entity.lotus_type == 'group' }
    end

    def find_entity(type, name, space, region, application, collection = nil)
      # Find an entity by type, name, space, region, and application
      collection ||= @entities
      collection.find do |entity|
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
        e.lotus_type == entity.lotus_type &&
          e.name == entity.name &&
          e.space == entity.space &&
          e.region == entity.region &&
          e.application == entity.application
      end
    end

    private

    def search_pattern_from_settings
      return nil unless @settings

      # Get the search pattern from CLI options stored in settings
      @settings.get('match')
    end

    def instantiate_all_environments
      return [] unless @settings

      environments = []
      target_environments = determine_target_environments(@settings)

      options = {}
      options[:space] = @settings.get('space') if @settings.get('space')
      options[:region] = @settings.get('region') if @settings.get('region')
      options[:application] = @settings.get('application') if @settings.get('application')

      target_environments.each do |env_name|
        environment = Lotus::Environment.new(
          env_name,
          **options,
          parent: self
        )
        environments << environment
      end

      environments
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
        next if find_entity('group', group_name, env.space, env.region, env.application, groups)

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

    def determine_target_environments(_settings)
      # this logic should probably be in the settings manager
      if @settings.get('group')
        # Get environments from the specified group
        @settings.groups[@settings.get('group')] || []
      elsif @settings.get('env')
        # Get environments from comma-separated list
        @settings.get('env').split(',').map(&:strip)
      else
        # Fallback: get all environments from all groups (original behavior)
        all_environments = []
        @settings.groups.each_value do |environment_names|
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
end
