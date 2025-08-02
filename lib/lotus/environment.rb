# frozen_string_literal: true

require_relative '../lall/cache_manager'

module Lotus
  class Environment
    attr_reader :name, :data, :application, :group, :entity_set

    def initialize(name, space: nil, region: nil, application: 'greenhouse', cache_manager: nil, entity_set: nil)
      @name = name
      @space = space
      @region = region
      @application = application
      @cache_manager = cache_manager || Lall::CacheManager.instance
      @entity_set = entity_set
      @data = nil # Will be loaded later via fetch method
      @group = nil # Will be loaded via fetch method
    end

    def self.from_yaml(yaml_obj)
      # For backward compatibility with YAML loading
      new(yaml_obj['environment'] || 'unknown')
    end

    # Legacy class method for backward compatibility
    def self.from_args(environment:, space: nil, region: nil, application: 'greenhouse')
      new(environment, space: space, region: region, application: application)
    end

    def configs
      raise NoMethodError, 'undefined method `configs` - requires data to be loaded first' if @data.nil?

      @data['configs'] || {}
    end

    def secret_keys
      raise NoMethodError, 'undefined method `secret_keys` - requires data to be loaded first' if @data.nil?

      Array(@data.dig('secrets', 'keys'))
    end

    def group_secret_keys
      raise NoMethodError, 'undefined method `group_secret_keys` - requires data to be loaded first' if @data.nil?

      Array(@data.dig('group_secrets', 'keys'))
    end

    def space
      @space || (@name.match?(/^(prod|staging)/) ? 'prod' : 'dev')
    end

    def region
      return @region if @region

      # Extract region from environment name
      if @name =~ /s(\d+)$/
        num = ::Regexp.last_match(1).to_i
        return 'use1' if num.between?(1, 99)
        return 'euc1' if num.between?(101, 199)
        return 'apse2' if num.between?(201, 299)

        return nil # Numbers outside defined ranges
      end

      # Default to use1 for environments without numbers
      'use1'
    end

    def fetch
      return @data if @data # Already loaded

      # Try to get from cache first
      cached_data = @cache_manager&.get_env_data(self)
      if cached_data
        @data = cached_data
        load_group_from_data
        return @data
      end

      # Cache miss - fetch from lotus
      fetch_from_lotus
    end

    private

    def fetch_from_lotus
      # Fetch environment YAML data
      yaml_data = Lotus::Runner.fetch_env_yaml(@name)
      return nil unless yaml_data

      # Build the data structure expected by the system
      @data = build_search_data(yaml_data)

      # Load group data if present
      load_group_from_data

      # Cache the environment data
      @cache_manager&.set_env_data(self, @data)

      @data
    end

    def build_search_data(yaml_data)
      search_data = {}

      # Add configs section
      search_data['configs'] = yaml_data['configs'] if yaml_data['configs']

      # Add secrets section (keys only, not values)
      if yaml_data['secrets'] && yaml_data['secrets']['keys']
        search_data['secrets'] = { 'keys' => yaml_data['secrets']['keys'] }
      end

      # Store group name for later group fetching
      search_data['group'] = yaml_data['group'] if yaml_data['group']

      search_data
    end

    def load_group_from_data
      return unless @data&.dig('group')

      # Try cache first
      cached_group_data = @cache_manager&.get_group_data(group_name, @application)
      if cached_group_data
        @group = Lotus::Group.new(cached_group_data)
        merge_group_secrets_into_data(cached_group_data)
        return
      end

      # Fetch group data from lotus
      group_yaml_data = Lotus::Runner.fetch_group_yaml(@name, group_name)
      return unless group_yaml_data

      @group = Lotus::Group.new(group_yaml_data)
      merge_group_secrets_into_data(group_yaml_data)

      # Cache group data
      @cache_manager&.set_group_data(group_name, @application, group_yaml_data)
    end

    def merge_group_secrets_into_data(group_yaml_data)
      return unless group_yaml_data['secrets'] && group_yaml_data['secrets']['keys']

      @data['group_secrets'] = { 'keys' => group_yaml_data['secrets']['keys'] }
    end

    public

    def group_name
      @data&.dig('group')
    end
  end
end
