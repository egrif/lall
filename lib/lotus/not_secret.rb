# frozen_string_literal: true

require_relative 'entity'

module Lotus
  # Base class for Lotus entities (Environment and Group)
  # Provides common functionality for data fetching and region/space logic
  class NotSecret < Entity
    attr_reader :name, :data, :application, :space, :region, :secrets
    attr_accessor :parent_entity

    def initialize(name, space: nil, region: nil, application: nil, parent: nil)
      super(name, space: space, region: region, application: application, parent: parent) # rubocop:disable Style/SuperArguments
      @secrets = []
    end

    def configs
      raise NoMethodError, 'undefined method `configs` - requires data to be loaded first' if @data.nil?

      return {} unless @data.is_a?(Hash)

      @data['configs'] || {}
    end

    def secret_keys
      raise NoMethodError, 'undefined method `secret_keys` - requires data to be loaded first' if @data.nil?

      return [] unless @data.is_a?(Hash)

      secrets_data = @data[key_to_secrets]
      return [] if secrets_data.nil?

      # Handle both formats:
      # 1. secrets: { keys: [...] }  (hash with keys)
      # 2. secrets: [...]            (direct array)
      if secrets_data.is_a?(Hash)
        Array(secrets_data['keys'])
      elsif secrets_data.is_a?(Array)
        secrets_data
      else
        []
      end
    end

    # Backward compatibility: entity_set should return the parent EntitySet
    def entity_set
      @parent_entity
    end

    # Allow setting entity_set for backward compatibility
    def entity_set=(value)
      @parent_entity = value
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

    def key_to_secrets
      raise NotImplementedError, 'Subclasses must implement key_to_secrets'
    end

    def lotus_parse(raw_data)
      @data = raw_data
      return if @data.nil?

      instantiate_secrets
      @data
    end

    def matched_secrets(pattern)
      return [] if @secrets.nil? || @secrets.empty?

      @secrets.filter do |secret|
        File.fnmatch(pattern, secret.name, File::FNM_CASEFOLD)
      end
    end

    private

    # Instantiate Secret objects for each secret key in the data
    def instantiate_secrets
      @secrets = []

      secret_keys.each do |secret_key|
        secret = create_secret(secret_key)
        @secrets << secret
      end
    end

    def create_secret(secret_key)
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
