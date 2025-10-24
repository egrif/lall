# frozen_string_literal: true

require_relative 'not_secret'

module Lotus
  class Environment < NotSecret
    attr_reader :group, :secrets

    def initialize(name, space: nil, region: nil, cluster: nil, application: 'greenhouse', parent: nil)
      vals = name.split(':')

      name = vals[0]
      parsed_space = vals[1] if vals.length > 1 && !vals[1].to_s.empty?
      parsed_region = vals[2] if vals.length > 2 && !vals[2].to_s.empty?

      # Handle cluster detection from parsed space: if space has at least 1 "-", it's a cluster
      if parsed_space&.include?('-')
        cluster = parsed_space
        space = nil
        region = nil
      else
        # Use parsed values if available, otherwise fall back to defaults
        space = parsed_space || space
        region = parsed_region || region

        # If no space/region specified but cluster is provided, use cluster
        if !space && !region && cluster
          # Keep the cluster, clear space/region
          space = nil
          region = nil
        end
      end

      super(name, space: space, region: region, cluster: cluster, application: application, parent: parent) # rubocop:disable Style/SuperArguments
    end

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
      if @cluster
        "lotus view --cluster #{@cluster} -e #{@name} -a #{@application} -G"
      else
        "lotus view -s #{space} -r #{region} -e #{@name} -a #{@application} -G"
      end
    end

    def key_to_secrets
      'secrets'
    end

    private

    def group_entity
      # Try to get the group entity from the parent EntitySet
      return nil unless @parent_entity.respond_to?(:groups)

      return nil unless group_name

      @parent_entity.groups.find { |group| group.name == group_name }
    end
  end
end
