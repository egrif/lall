# lib/lall/key_searcher.rb
class KeySearcher
  def self.search(obj, search_str, path = [], results = [], insensitive = false, env: nil, expose: false)
    secret_jobs = []
    case obj
    when Hash
      obj.each do |k, v|
        key_str = k.to_s
        match = insensitive ? key_str.downcase.include?(search_str.downcase) : key_str.include?(search_str)
        if match
          if expose && (path.include?('secrets') || path.include?('group_secrets')) && env
            # Instead of fetching here, queue a job for later
            secret_jobs << { env: env, key: k, path: (path + [k]).join('.'), k: k }
            results << { path: (path + [k]).join('.'), key: k, value: :__PENDING_SECRET__ }
          else
            results << { path: (path + [k]).join('.'), key: k, value: v }
          end
        end
        search(v, search_str, path + [k], results, insensitive, env: env, expose: expose)
      end
    when Array
      obj.each_with_index do |v, i|
        key_str = v.to_s
        match = insensitive ? key_str.downcase.include?(search_str.downcase) : key_str.include?(search_str)
        if match
          if expose && (path.include?('secrets') || path.include?('group_secrets')) && env
            secret_jobs << { env: env, key: v, path: (path + [i]).join('.'), k: v }
            results << { path: (path + [i]).join('.'), key: v, value: :__PENDING_SECRET__ }
          else
            results << { path: (path + [i]).join('.'), key: v, value: '{SECRET}' }
          end
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
