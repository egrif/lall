# frozen_string_literal: true

module Lotus
  class Environment
    attr_reader :data

    def initialize(yaml_hash)
      @data = yaml_hash
    end

    def self.from_yaml(yaml_obj)
      new(yaml_obj)
    end

    def group
      @data['group']
    end

    def configs
      @data['configs'] || {}
    end

    def secret_keys
      Array(@data.dig('secrets', 'keys'))
    end

    def group_secret_keys
      Array(@data.dig('group_secrets', 'keys'))
    end

    # Add more convenience methods as needed

    def self.from_args(environment:, space: nil, region: nil, application: 'greenhouse')
      # Set defaults for space (s_arg) and region (r_arg) based on logic from LotusRunner.get_lotus_args
      space_val = if environment.start_with?('prod') || environment.start_with?('staging')
                    'prod'
                  else
                    environment
                  end
      region_val = nil
      if environment =~ /s(\d+)$/
        num = ::Regexp.last_match(1).to_i
        if num.between?(1, 99)
          region_val = 'use1'
        elsif num.between?(101, 199)
          region_val = 'euc1'
        elsif num.between?(201, 299)
          region_val = 'apse2'
        end
      end
      # Return a new instance with a hash containing these values
      new({
            'environment' => environment,
            'space' => space || space_val,
            'region' => region || region_val,
            'application' => application
          })
    end
  end
end
