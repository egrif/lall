# frozen_string_literal: true

require_relative 'environment'

module Lotus
  class EntitySet
    attr_reader :entities, :settings

    def initialize(entities_or_settings = [], settings = nil)
      # If first parameter is a SettingsManager, create entities from it
      if entities_or_settings.respond_to?(:groups)
        @settings = entities_or_settings
        @entities = create_environments_from_settings(@settings)

        # Set entity_set reference on each environment
        @entities.each do |environment|
          environment.instance_variable_set(:@entity_set, self)
        end
      else
        # Traditional initialization with entities array
        @entities = entities_or_settings
        @settings = settings
      end
    end

    def add(entity)
      @entities << entity
      # Set entity_set reference if the entity supports it
      entity.instance_variable_set(:@entity_set, self) if entity.respond_to?(:entity_set)
    end

    def remove(entity)
      @entities.delete(entity)
      # Clear entity_set reference if the entity supports it
      entity.instance_variable_set(:@entity_set, nil) if entity.respond_to?(:entity_set)
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

    # Get all unique group names that environments belong to
    def group_names
      return [] unless @settings

      groups = []
      @settings.groups.each do |group_name, environment_names|
        @entities.each do |entity|
          groups << group_name if environment_names.include?(entity.name) && !groups.include?(group_name)
        end
      end
      groups
    end

    private

    def create_environments_from_settings(settings)
      environments = []
      cache_manager = initialize_cache_manager(settings)

      # Get all environments from groups in settings
      settings.groups.each_value do |environment_names|
        environment_names.each do |env_name|
          # Skip duplicates - same environment might be in multiple groups
          next if environments.any? { |env| env.name == env_name }

          # Create Environment instance - it will use singleton cache manager unless overridden
          environment = Lotus::Environment.new(
            env_name,
            cache_manager: cache_manager,
            entity_set: self
          )
          environments << environment
        end
      end

      environments
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
