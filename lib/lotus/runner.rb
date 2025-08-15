# frozen_string_literal: true

require 'open3'
require 'yaml'
require_relative '../lall/settings_manager'

module Lotus
  class Runner
    TEST_MODE = ENV['RSPEC_CORE_VERSION'] || ENV['RAILS_ENV'] == 'test' || ENV['RACK_ENV'] == 'test'

    def self.fetch(entity)
      @debug_mode = Lall::SettingsManager.instance.get('debug')
      start_time = Time.now if @debug_mode

      # Check cache first based on entity type
      cache_manager = self.cache_manager
      cached_data = cached_data_for_entity(entity, cache_manager)
      if cached_data
        entity.lotus_parse(cached_data)
        if @debug_mode
          elapsed = Time.now - start_time
          puts "DEBUG: #{entity.lotus_type} '#{entity.name}' - loaded from cache in #{elapsed.round(3)}s"
        end
        return cached_data
      end

      # Cache miss - fetch from lotus using existing methods for backward compatibility
      puts "DEBUG: #{entity.lotus_type} '#{entity.name}' - cache miss, fetching from lotus..." if @debug_mode

      fetch_start_time = Time.now if @debug_mode
      raw_data = fetch_yaml(entity)
      fetch_end_time = Time.now if @debug_mode

      return nil unless raw_data

      # Let the entity parse the data
      entity.lotus_parse(raw_data)

      # Cache the raw data, not the parsed result
      set_cached_data_for_entity(entity, cache_manager, raw_data)

      if @debug_mode
        total_elapsed = Time.now - start_time
        fetch_elapsed = fetch_end_time - fetch_start_time
        entity_type = entity.class.name.split('::').last
        fetch_time = fetch_elapsed.round(3)
        total_time = total_elapsed.round(3)
        puts "DEBUG: #{entity_type} '#{entity.name}' - fetched from lotus in #{fetch_time}s, total time #{total_time}s"
      end

      raw_data
    end

    def self.fetch_all(entities)
      return [] if entities.empty?

      puts "DEBUG: Fetching #{entities.map(&:name).join(', ')} in parallel..." if @debug_mode

      # ping the spaces to avoid reauthorizing for each entity
      spaces = entities.map { |e| e.respond_to?(:space) ? e.space : 'prod' }.uniq
      ping_all(spaces)

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

    def self.should_instantiate_secrets?(_entity)
      # Secrets are now instantiated on-demand during search, not automatically
      false
    end

    def self.fetch_yaml(entity)
      lotus_cmd = entity.lotus_cmd
      puts "DEBUG: Executing: #{lotus_cmd}" if @debug_mode

      yaml_output = nil
      Open3.popen3(lotus_cmd) do |_stdin, stdout, stderr, wait_thr|
        yaml_output = stdout.read
        unless wait_thr.value.success?
          warn "Failed to run lotus command for entity '#{entity.name}': #{stderr.read}" unless TEST_MODE
          return nil
        end
      end

      puts 'DEBUG: Lotus command completed successfully, parsing YAML...' if @debug_mode

      YAML.safe_load(yaml_output)
    end

    def self.ping(space)
      # Use the environment's space for the ping command
      ping_cmd = "lotus ping -s #{space} > /dev/null 2>&1"
      system(ping_cmd)
    end

    def self.ping_all(spaces)
      spaces.each do |space|
        ping(space)
      end
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
      has_secrets = case entity.class.name
                    when 'Lotus::Secret'
                      true
                    when 'Lotus::Environment', 'Lotus::Group'
                      data.is_a?(Hash) && (data.key?('secrets') || data.key?('group_secrets'))
                    else
                      false
                    end

      cache_manager.set_entity_data(entity, data, is_secret: has_secrets)
    end
  end
end
