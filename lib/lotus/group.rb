module Lotus
  class Group
    attr_reader :data

    def initialize(yaml_hash)
      @data = yaml_hash
    end

    def configs
      @data['configs'] || {}
    end

    def secrets
      Array(@data.dig('secrets', 'keys'))
    end
  end
end
