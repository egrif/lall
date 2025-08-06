# frozen_string_literal: true

require 'open3'
require 'yaml'

module Lotus
  class Runner
    DEBUG_MODE = ARGV.include?('-d') || ARGV.include?('--debug') || ENV.fetch('DEBUG', nil)
    TEST_MODE = ENV['RSPEC_CORE_VERSION'] || ENV['RAILS_ENV'] == 'test' || ENV['RACK_ENV'] == 'test'

    def self.fetch(entity)
      # Check cache first based on entity type
      cache_manager = self.cache_manager
      cached_data = cached_data_for_entity(entity, cache_manager)
      if cached_data
        entity.instance_variable_set(:@data, cached_data)
        return cached_data
      end

      # Cache miss - fetch from lotus using existing methods for backward compatibility
      raw_data = fetch_yaml(entity)

      return nil unless raw_data

      # Let the entity parse the data
      parsed_data = entity.lotus_parse(raw_data)
      return nil unless parsed_data

      # Cache the result
      set_cached_data_for_entity(entity, cache_manager, parsed_data)

      parsed_data
    end

    def self.fetch_all(entities)
      return [] if entities.empty?

      # Use threading to fetch all entities in parallel
      threads = entities.map do |entity|
        Thread.new do
          fetch(entity)
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Return array of entities with loaded data
      entities
    end

    def self.fetch_yaml(entity)
      lotus_cmd = entity.lotus_cmd
      yaml_output = nil
      Open3.popen3(lotus_cmd) do |_stdin, stdout, stderr, wait_thr|
        yaml_output = stdout.read
        unless wait_thr.value.success?
          warn "Failed to run lotus command for entity '#{entity.name}': \\#{stderr.read}" unless TEST_MODE
          return nil
        end
      end
      YAML.safe_load(yaml_output)
    end

    def self.secret_get(env, secret_key, group: nil)
      s_arg, r_arg = get_lotus_args(env)
      lotus_cmd = if group
                    "lotus secret get #{secret_key} -s \\#{s_arg} -g \\#{group} -a greenhouse "
                  else
                    "lotus secret get #{secret_key} -s \\#{s_arg} -e \\#{env} -a greenhouse "
                  end
      lotus_cmd += " -r \\#{r_arg}" if r_arg
      # puts lotus_cmd if DEBUG_MODE
      secret_output = nil
      Open3.popen3(lotus_cmd) do |_stdin, stdout, stderr, wait_thr|
        secret_output = stdout.read
        unless wait_thr.value.success?
          warn "Failed to run lotus secret get for env '#{env}', key '#{secret_key}': \\#{stderr.read}" unless TEST_MODE
          return nil
        end
      end
      # Expect output like KEY=value, return just the value
      if secret_output =~ /^\s*\w+\s*=\s*(.*)$/
        ::Regexp.last_match(1).strip
      else
        secret_output.strip
      end
    end

    def self.secret_get_many(env, secret_keys)
      results = {}
      threads = secret_keys.map do |key|
        Thread.new do
          value = secret_get(env, key)
          results[key] = value
        end
      end
      threads.each(&:join)
      results
    end

    def self.ping(env)
      s_arg, = get_lotus_args(env)
      ping_cmd = "lotus ping -s \\#{s_arg} > /dev/null 2>&1"
      system(ping_cmd)
    end

    def self.get_lotus_args(env)
      # Determine space argument based on environment prefix
      s_arg = if env.match?(/^(prod|staging)/)
                'prod'
              else
                env
              end

      # Determine region argument based on environment suffix
      r_arg = if env =~ /s(\d+)$/
                num = ::Regexp.last_match(1).to_i
                if num.between?(1, 99)
                  'use1'
                elsif num.between?(101, 199)
                  'euc1'
                elsif num.between?(201, 299)
                  'apse2'
                end
              end

      [s_arg, r_arg]
    end

    def self.cache_manager
      require_relative '../lall/cache_manager'
      Lall::CacheManager.instance
    end

    def self.cached_data_for_entity(entity, cache_manager)
      return nil unless cache_manager.respond_to?(:get_entity_data)

      cache_manager.get_entity_data(entity)
    end

    def self.set_cached_data_for_entity(entity, cache_manager, data)
      return false unless cache_manager.respond_to?(:set_entity_data)

      # Determine if this data contains secrets for proper encryption
      has_secrets = case entity
                    when Secret
                      true
                    when Environment, Group
                      data.key?('secrets') || data.key?('group_secrets')
                    else
                      false
                    end

      cache_manager.set_entity_data(entity, data, is_secret: has_secrets)
    end
  end
end
