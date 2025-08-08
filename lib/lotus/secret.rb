# frozen_string_literal: true

require_relative 'entity'

module Lotus
  class Secret < Entity
    # Implement abstract methods from Entity
    def lotus_cmd
      cmd = "lotus secret get #{name} -s #{space} -r #{region} -a #{@application}"
      cmd += secret_type == 'group' ? ' -g ' : ' -e '
      cmd += parent_entity.name.to_s
      cmd
    end

    def lotus_parse(raw_data)
      # Groups use the raw data as-is
      if raw_data =~ /^\s*\w+\s*=\s*(.*)$/
        ::Regexp.last_match(1).strip
      else
        raw_data.strip
      end
    end

    def secret_type
      parent_entity.is_a?(Lotus::Group) ? 'group' : 'environment'
    end

    def group
      secret_type == 'group' ? parent_entity : nil
    end

    def environment
      secret_type == 'environment' ? parent_entity : nil
    end

    def cache_key_type
      # override to identify secret types and create unique key
      "#{secret_type}_#{self.class.name.split('::').last.downcase}_#{parent_entity.name}"
    end
  end
end
