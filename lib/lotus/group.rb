# frozen_string_literal: true

require_relative 'not_secret'

module Lotus
  class Group < NotSecret
    attr_reader :secrets

    def key_to_secrets
      'group_secrets'
    end

    # Implement abstract methods from Entity
    def lotus_cmd
      if @cluster
        "lotus view --cluster #{@cluster} -a #{@application} -g #{@name}"
      else
        "lotus view -s #{space} -r #{region} -a #{application} -g #{name}"
      end
    end
  end
end
