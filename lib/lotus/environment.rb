# frozen_string_literal: true

module Lotus
  class Environment
    attr_reader :name, :data, :application

    def initialize(name, space: nil, region: nil, application: 'greenhouse')
      @name = name
      @space = space
      @region = region
      @application = application
      @data = nil # Will be loaded later via fetch method
    end

    def self.from_yaml(yaml_obj)
      # For backward compatibility with YAML loading
      new(yaml_obj['environment'] || 'unknown')
    end

    def group
      @data&.dig('group')
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
      # Placeholder for future implementation
      # This method would load @data from lotus commands
      raise NotImplementedError, 'fetch method not yet implemented'
    end

    def group_name
      # This would need @data to be loaded first
      raise NoMethodError, 'undefined method `group_name\' - requires data to be loaded first' if @data.nil?

      @data['group_name']
    end

    # Legacy class method for backward compatibility
    def self.from_args(environment:, space: nil, region: nil, application: 'greenhouse')
      new(environment, space: space, region: region, application: application)
    end
  end
end
