# frozen_string_literal: true

# lib/lall/key_searcher.rb
require 'lotus/environment'
require 'lotus/group'
require 'lotus/runner'

class KeySearcher
  def self.match_key?(key_str, search_str)
    if search_str.include?('*')
      regex = Regexp.new("^#{Regexp.escape(search_str).gsub('\\*', '.*')}$")
      regex.match?(key_str)
    else
      key_str == search_str
    end
  end

  def self.handle_secret_match(results, secret_jobs, path, key, value, expose, env, idx: nil)
    match_options = {
      path: path,
      key: key,
      value: value,
      expose: expose,
      env: env,
      idx: idx
    }

    add_result_to_collection(results, secret_jobs, match_options)
  end

  def self.add_result_to_collection(results, secret_jobs, options)
    match_path = (options[:path] + [(options[:idx].nil? ? options[:key] : options[:idx])]).join('.')

    if should_expose_secret?(options)
      secret_jobs << { env: options[:env], key: options[:key], path: match_path, k: options[:key] }
      results << { path: match_path, key: options[:key], value: :__PENDING_SECRET__ }
    else
      results << { path: match_path, key: options[:key], value: options[:value] }
    end
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
                  root_obj: nil, insensitive: false, cache_manager: nil)
    root_obj ||= obj
    secret_jobs = []

    perform_object_search(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive)
    process_secret_jobs(secret_jobs, root_obj, results, cache_manager) if expose && env && !secret_jobs.empty?

    results
  end

  def self.perform_object_search(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive)
    case obj
    when Hash
      search_hash_object(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive)
    when Array
      search_array_object(obj, search_str, path, results, secret_jobs, env, expose)
    end
  end

  def self.search_hash_object(obj, search_str, path, results, secret_jobs, env, expose, root_obj, insensitive)
    obj.each do |k, v|
      key_str = k.to_s
      handle_secret_match(results, secret_jobs, path, k, v, expose, env) if match_key?(key_str, search_str)
      search(v, search_str, path + [k], results, env: env, expose: expose, root_obj: root_obj, insensitive: insensitive)
    end
  end

  def self.search_array_object(obj, search_str, path, results, secret_jobs, env, expose)
    obj.each_with_index do |v, i|
      key_str = v.to_s
      handle_secret_match(results, secret_jobs, path, v, '{SECRET}', expose, env, idx: i) if match_key?(key_str,
                                                                                                        search_str)
    end
  end

  def self.process_secret_jobs(secret_jobs, root_obj, results, cache_manager = nil)
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
    
    # Try cache first if available
    secret_val = nil
    if cache_manager
      cache_key = "secret:#{job[:env]}:#{job[:key]}"
      cache_key += ":#{group}" if group
      secret_val = cache_manager.get(cache_key, is_secret: true)
    end
    
    # Fetch from lotus if not cached
    if secret_val.nil?
      secret_val = Lotus::Runner.secret_get(job[:env], job[:key], group: group)
      secret_val = parse_secret_value(secret_val)
      
      # Cache the secret if cache manager is available
      if cache_manager && secret_val
        cache_key = "secret:#{job[:env]}:#{job[:key]}"
        cache_key += ":#{group}" if group
        cache_manager.set(cache_key, secret_val, is_secret: true)
      end
    end
    
    update_secret_results(mutex, results, job, secret_val)
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
