# frozen_string_literal: true

require_relative 'not_secret'

module Lotus
  class Environment < NotSecret
    attr_reader :group, :secrets

    def group_name
      raise NoMethodError, 'undefined method `group_name` - requires data to be loaded first' if @data.nil?

      return nil unless @data.is_a?(Hash)

      @data['group']
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

    def key_to_secrets
      'secrets'
    end

    private

    def group_entity
      # Try to get the group entity from the parent EntitySet
      return nil unless @parent_entity.respond_to?(:groups)

      group_name = @data&.dig('group')
      return nil unless group_name

      @parent_entity.groups.find { |group| group.name == group_name }
    end
  end
end
