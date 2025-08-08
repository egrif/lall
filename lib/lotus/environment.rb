# frozen_string_literal: true

require_relative 'entity'

module Lotus
  class Environment < Entity
    attr_reader :group, :secrets

    def initialize(*args, **kwargs)
      super
      @secrets = []
    end

    # Backward compatibility: entity_set should return the parent EntitySet
    def entity_set
      @parent_entity
    end

    # Allow setting entity_set for backward compatibility
    def entity_set=(value)
      @parent_entity = value
    end

    # attributes from data
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

    def group_name
      raise NoMethodError, 'undefined method `group_name` - requires data to be loaded first' if @data.nil?

      @data&.dig('group')
    end

    # Environment defaults
    def space
      @space || (@name.match?(/^(prod|staging)/) ? 'prod' : 'dev')
    end

    def region
      return @region if @region

      # Extract region from entity name
      if @name =~ /s(\d+)$/
        num = ::Regexp.last_match(1).to_i
        return 'use1' if num.between?(1, 99)
        return 'euc1' if num.between?(101, 199)
        return 'apse2' if num.between?(201, 299)

        return nil # Numbers outside defined ranges
      end

      # Default to use1 for entities without numbers
      'use1'
    end

    # Implement abstract methods from Entity
    def lotus_cmd
      "lotus view -s #{space} -r #{region} -e #{@name} -a #{@application} -G"
    end

    private

    def find_matching_secret_keys(pattern)
      matching_keys = []

      # Convert glob pattern to regex
      regex_pattern = glob_to_regex(pattern)

      # Check environment secret keys
      secret_keys.each do |key|
        matching_keys << { key: key, source_entity: self } if key.match?(regex_pattern)
      end


      matching_keys
    end

    def group_entity
      # Try to get the group entity from the parent EntitySet
      return nil unless @parent_entity.respond_to?(:groups)

      group_name = @data&.dig('group')
      return nil unless group_name

      @parent_entity.groups.find { |group| group.name == group_name }
    end

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
