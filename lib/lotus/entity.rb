# frozen_string_literal: true

require_relative '../lall/settings_manager'

module Lotus
  # Base class for Lotus entities (Environment and Group)
  # Provides common functionality for data fetching and region/space logic
  class Entity
    attr_reader :name, :data, :application, :space, :region, :cluster, :secrets
    attr_accessor :parent_entity

    def initialize(name, space: nil, region: nil, cluster: nil, application: 'greenhouse', parent: nil)
      @name = name
      @space = space
      @region = region
      @cluster = cluster
      @application = application
      @data = nil # Will be loaded later via fetch method
      @secrets = [] # Will be populated after data is loaded
      @settings = Lall::SettingsManager.instance
      @parent_entity = parent
    end

    def clear_cache
      require_relative '../lall/cache_manager'
      Lall::CacheManager.instance&.purge_entity(self)
      @data = nil
    end

    # Abstract methods to be implemented by subclasses
    def lotus_cmd
      raise NotImplementedError, 'Subclasses must implement lotus_cmd'
    end

    def lotus_parse(raw_data)
      @data = raw_data
      @data
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
  end
end
