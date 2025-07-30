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
    match_path = (path + [(idx.nil? ? key : idx)]).join('.')
    if expose && (path.include?('secrets') || path.include?('group_secrets')) && env
      secret_jobs << { env: env, key: key, path: match_path, k: key }
      results << { path: match_path, key: key, value: :__PENDING_SECRET__ }
    else
      # For arrays, value should be '{SECRET}', for hashes, it's the actual value
      results << { path: match_path, key: key, value: value }
    end
  end

  def self.find_group(obj)
    # The group is a value at the root of the YAML hash
    obj.is_a?(Hash) ? obj['group'] : nil
  end

  def self.search(obj, search_str, path = [], results = [], insensitive = false, env: nil, expose: false,
                  root_obj: nil, debug: false)
    root_obj ||= obj
    secret_jobs = []
    case obj
    when Hash
      obj.each do |k, v|
        key_str = k.to_s
        handle_secret_match(results, secret_jobs, path, k, v, expose, env) if match_key?(key_str, search_str)
        search(v, search_str, path + [k], results, insensitive, env: env, expose: expose, root_obj: root_obj)
      end
    when Array
      obj.each_with_index do |v, i|
        key_str = v.to_s
        if match_key?(key_str, search_str)
          handle_secret_match(results, secret_jobs, path, v, '{SECRET}', expose, env, idx: i)
        end
      end
    end
    # After traversal, if there are secret jobs, run them in parallel and update results
    if expose && env && !secret_jobs.empty?
      group_name = find_group(root_obj)
      mutex = Mutex.new
      threads = secret_jobs.map do |job|
        Thread.new do
          group = job[:path].include?('group_secrets') ? group_name : nil
          secret_val = Lotus::Runner.secret_get(job[:env], job[:key], group: group)
          # Extract only the part after the first '='
          secret_val = secret_val.split('=', 2)[1].strip if secret_val&.include?('=')
          mutex.synchronize do
            results.each do |r|
              r[:value] = secret_val if r[:path] == job[:path] && r[:key] == job[:k] && r[:value] == :__PENDING_SECRET__
            end
          end
        end
      end
      threads.each(&:join)
    end
    results
  end
end
