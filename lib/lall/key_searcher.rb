# frozen_string_literal: true

# lib/lall/key_searcher.rb
require 'lotus/environment'
require 'lotus/group'
require 'lotus/runner'

# rubocop:disable Metrics/ClassLength
class KeySearcher
  def self.match_key?(key_str, search_str)
    if search_str.include?('*')
      regex = Regexp.new("^#{Regexp.escape(search_str).gsub('\\*', '.*')}$")
      regex.match?(key_str)
    else
      key_str == search_str
    end
  end

  def self.handle_secret_match(results, secret_jobs, path, key, value, expose, env, search_data: nil, idx: nil)
    match_options = {
      path: path,
      key: key,
      value: value,
      expose: expose,
      env: env,
      idx: idx,
      search_data: search_data
    }

    add_result_to_collection(results, secret_jobs, match_options)
  end

  def self.add_result_to_collection(results, secret_jobs, options)
    match_path = (options[:path] + [(options[:idx].nil? ? options[:key] : options[:idx])]).join('.')
    color = determine_value_color(options)

    if should_expose_secret?(options)
      secret_jobs << { env: options[:env], key: options[:key], path: match_path, k: options[:key], color: color }
      results << { path: match_path, key: options[:key], value: :__PENDING_SECRET__, color: color }
    else
      results << { path: match_path, key: options[:key], value: options[:value], color: color }
    end
  end

  def self.determine_value_color(options)
    return nil unless options[:search_data] && options[:path] && options[:key]

    path_array = options[:path]
    is_env_value = %w[configs secrets].include?(path_array.first)
    is_group_value = %w[group_configs group_secrets].include?(path_array.first)

    return determine_env_value_color(options) if is_env_value
    return determine_group_value_color(options) if is_group_value

    nil # No color for other paths
  end

  def self.determine_env_value_color(options)
    path_array = options[:path]
    key = options[:key]
    search_data = options[:search_data]
    current_value = options[:value]

    group_path_array = build_corresponding_group_path(path_array)
    group_path_str = (group_path_array + [key]).join('.')
    group_value = get_value_from_path(search_data, group_path_str)

    return :white unless group_value
    return :blue if current_value == group_value

    :yellow # Environment overrides group
  end

  def self.determine_group_value_color(options)
    path_array = options[:path]
    key = options[:key]
    search_data = options[:search_data]

    env_path_array = build_corresponding_env_path(path_array)
    env_path_str = (env_path_array + [key]).join('.')
    env_value = get_value_from_path(search_data, env_path_str)

    return nil if env_value

    :green # Group value, no override
  end

  def self.build_corresponding_group_path(path_array)
    if path_array.first == 'configs'
      ['group_configs'] + path_array[1..]
    elsif path_array.first == 'secrets'
      ['group_secrets'] + path_array[1..]
    end
  end

  def self.build_corresponding_env_path(path_array)
    if path_array.first == 'group_configs'
      ['configs'] + path_array[1..]
    elsif path_array.first == 'group_secrets'
      ['secrets'] + path_array[1..]
    end
  end

  def self.get_value_from_path(data, path)
    return nil unless data && path

    # Convert path to array if it's a string
    path_parts = if path.is_a?(String)
                   path.split('.')
                 elsif path.is_a?(Array)
                   path.map(&:to_s)
                 else
                   return nil
                 end

    current = data
    path_parts.each do |part|
      return nil unless current.is_a?(Hash) && current.key?(part)

      current = current[part]
    end
    current
  end

  def self.should_expose_secret?(options)
    options[:expose] &&
      (options[:path].include?('secrets') || options[:path].include?('group_secrets')) &&
      options[:env]
  end

  def self.find_group(obj)
    # The group is a value at the root of the YAML hash
    obj.is_a?(Hash) ? obj['group'] : nil
  end

  def self.search(obj, search_str, path = [], results = [], env: nil, expose: false,
                  root_obj: nil, insensitive: false, cache_manager: nil, search_data: nil)
    root_obj ||= obj
    search_data ||= obj
    secret_jobs = []

    perform_object_search(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive, search_data, cache_manager)
    process_secret_jobs(secret_jobs, root_obj, results, cache_manager) if expose && env && !secret_jobs.empty?

    results
  end

  def self.perform_object_search(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive,
                                 search_data, cache_manager)
    case obj
    when Hash
      search_hash_object(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive, search_data, cache_manager)
    when Array
      search_array_object(obj, search_str, path, results, secret_jobs, env, expose, search_data)
    end
  end

  def self.search_hash_object(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive,
                              search_data, cache_manager)
    obj.each do |k, v|
      key_str = k.to_s
      search_term = insensitive ? search_str.downcase : search_str
      key_match = insensitive ? key_str.downcase : key_str

      if match_key?(key_match, search_term)
        handle_secret_match(results, secret_jobs, path, k, v, expose, env, search_data: search_data)
      end
      search(v, search_str, path + [k], results, env: env, expose: expose, root_obj: root_obj,
                                                 insensitive: insensitive, cache_manager: cache_manager, search_data: search_data)
    end
  end

  def self.search_array_object(obj, search_str, path, results, secret_jobs, env, expose, search_data)
    obj.each_with_index do |v, i|
      key_str = v.to_s
      if match_key?(key_str, search_str)
        handle_secret_match(results, secret_jobs, path, v, '{SECRET}', expose, env,
                            search_data: search_data, idx: i)
      end
    end
  end

  def self.process_secret_jobs(secret_jobs, root_obj, results, cache_manager = nil)
    return if secret_jobs.empty?
    
    group_name = find_group(root_obj)
    mutex = Mutex.new
    threads = create_secret_fetch_threads(secret_jobs, group_name, mutex, results, cache_manager)
    threads.each(&:join)
  end

  def self.create_secret_fetch_threads(secret_jobs, group_name, mutex, results, cache_manager)
    secret_jobs.map do |job|
      Thread.new do
        fetch_and_update_secret(job, group_name, mutex, results, cache_manager)
      end
    end
  end

  def self.fetch_and_update_secret(job, group_name, mutex, results, cache_manager)
    group = job[:path].include?('group_secrets') ? group_name : nil
    s_arg, r_arg = Lotus::Runner.get_lotus_args(job[:env])

    secret_val = try_cache_lookup(cache_manager, job, group, s_arg, r_arg)
    if secret_val.nil?
      secret_val = fetch_and_cache_secret(cache_manager, job, group, s_arg, r_arg)
    end

    update_secret_results(mutex, results, job, secret_val)
  end

  def self.try_cache_lookup(cache_manager, job, group, s_arg, r_arg)
    return nil unless cache_manager

    env_secret_key = generate_secret_cache_key('ENV-SECRET', job[:env], s_arg, r_arg, job[:key])
    secret_val = cache_manager.get(env_secret_key)

    if group
      group_secret_key = generate_secret_cache_key('GROUP-SECRET', group, s_arg, r_arg, job[:key])
      secret_val ||= cache_manager.get(group_secret_key)
    end

    secret_val
  end

  def self.fetch_and_cache_secret(cache_manager, job, group, s_arg, r_arg)
    # Try environment secret first
    secret_val = fetch_env_secret(cache_manager, job, s_arg, r_arg)

    # Try group secret if environment secret not found and we have a group
    secret_val ||= fetch_group_secret(cache_manager, job, group, s_arg, r_arg) if group

    secret_val
  end

  def self.fetch_env_secret(cache_manager, job, s_arg, r_arg)
    env_secret = Lotus::Runner.secret_get(job[:env], job[:key])
    return nil unless env_secret

    secret_val = parse_secret_value(env_secret)
    cache_env_secret(cache_manager, job, s_arg, r_arg, secret_val)
    secret_val
  end

  def self.fetch_group_secret(cache_manager, job, group, s_arg, r_arg)
    group_secret = Lotus::Runner.secret_get(job[:env], job[:key], group: group)
    return nil unless group_secret

    secret_val = parse_secret_value(group_secret)
    cache_group_secret(cache_manager, group, s_arg, r_arg, job[:key], secret_val)
    secret_val
  end

  def self.cache_env_secret(cache_manager, job, s_arg, r_arg, secret_val)
    return unless cache_manager

    env_secret_key = generate_secret_cache_key('ENV-SECRET', job[:env], s_arg, r_arg, job[:key])
    cache_manager.set(env_secret_key, secret_val, is_secret: true)
  end

  def self.cache_group_secret(cache_manager, group, s_arg, r_arg, key, secret_val)
    return unless cache_manager

    group_secret_key = generate_secret_cache_key('GROUP-SECRET', group, s_arg, r_arg, key)
    cache_manager.set(group_secret_key, secret_val, is_secret: true)
  end

  def self.generate_secret_cache_key(type, env_or_group, s_arg, r_arg, secret_key)
    # Ensure every key has a region - use 'use1' as default for base environments
    region = r_arg || 'use1'
    [type, env_or_group, s_arg, region, secret_key].join('.')
  end

  def self.parse_secret_value(secret_val)
    return secret_val unless secret_val&.include?('=')

    secret_val.split('=', 2)[1].strip
  end

  def self.update_secret_results(mutex, results, job, secret_val)
    mutex.synchronize do
      results.each do |r|
        next unless secret_result_matches?(r, job)

        r[:value] = secret_val
      end
    end
  end

  def self.secret_result_matches?(result, job)
    result[:path] == job[:path] && result[:key] == job[:k] && result[:value] == :__PENDING_SECRET__
  end
end
# rubocop:enable Metrics/ClassLength
