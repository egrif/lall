# frozen_string_literal: true

require_relative 'entity'

module Lotus
  class Group < Entity
    def configs
      raise NoMethodError, 'undefined method `configs` - requires data to be loaded first' if @data.nil?

      @data['configs'] || {}
    end

    def secrets
      raise NoMethodError, 'undefined method `secrets` - requires data to be loaded first' if @data.nil?

      Array(@data.dig('secrets', 'keys'))
    end

    # Implement abstract methods from Entity
    def lotus_cmd
      "lotus view -s \\#{space} -r \\#{region} -a #{@application} -g \\#{@name}"
    end

  end
end
