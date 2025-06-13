# lib/lall/key_searcher.rb
class KeySearcher
  def self.match_key?(key_str, search_str)
    if search_str.include?("*")
      regex = Regexp.new('^' + Regexp.escape(search_str).gsub('\\*', '.*') + '$')
      regex.match?(key_str)
    else
      key_str == search_str
    end
  end

  def self.handle_secret_match(results, secret_jobs, path, key, value, expose, env)
    if expose && (path.include?('secrets') || path.include?('group_secrets')) && env
      secret_jobs << { env: env, key: key, path: (path + [key]).join('.'), k: key }
      results << { path: (path + [key]).join('.'), key: key, value: :__PENDING_SECRET__ }
    else
      results << { path: (path + [key]).join('.'), key: key, value: value }
    end
  end

  def self.handle_array_secret_match(results, secret_jobs, path, idx, key, expose, env)
    if expose && (path.include?('secrets') || path.include?('group_secrets')) && env
      secret_jobs << { env: env, key: key, path: (path + [idx]).join('.'), k: key }
      results << { path: (path + [idx]).join('.'), key: key, value: :__PENDING_SECRET__ }
    else
      results << { path: (path + [idx]).join('.'), key: key, value: '{SECRET}' }
    end
  end

  def self.search(obj, search_str, path = [], results = [], insensitive = false, env: nil, expose: false)
    secret_jobs = []
    case obj
    when Hash
      obj.each do |k, v|
        key_str = k.to_s
        if match_key?(key_str, search_str)
          handle_secret_match(results, secret_jobs, path, k, v, expose, env)
        end
        search(v, search_str, path + [k], results, insensitive, env: env, expose: expose)
      end
    when Array
      obj.each_with_index do |v, i|
        key_str = v.to_s
        if match_key?(key_str, search_str)
          handle_array_secret_match(results, secret_jobs, path, i, v, expose, env)
        end
      end
    end
    # After traversal, if there are secret jobs, run them in parallel and update results
    if expose && env && !secret_jobs.empty?
      mutex = Mutex.new
      threads = secret_jobs.map do |job|
        Thread.new do
          secret_val = LotusRunner.secret_get(job[:env], job[:key])
          # Extract only the part after the first '='
          if secret_val && secret_val.include?("=")
            secret_val = secret_val.split("=", 2)[1].strip
          end
          mutex.synchronize do
            results.each do |r|
              if r[:path] == job[:path] && r[:key] == job[:k] && r[:value] == :__PENDING_SECRET__
                r[:value] = secret_val
              end
            end
          end
        end
      end
      threads.each(&:join)
    end
    results
  end
end
