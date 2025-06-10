# lib/lall/key_searcher.rb
class KeySearcher
  def self.search(obj, search_str, path = [], results = [], insensitive = false, env: nil, expose: false)
    case obj
    when Hash
      obj.each do |k, v|
        key_str = k.to_s
        match = insensitive ? key_str.downcase.include?(search_str.downcase) : key_str.include?(search_str)
        if match
          # If this key is a descendant of secrets/group_secrets and expose is set, fetch the secret
          if expose && (path.include?('secrets') || path.include?('group_secrets')) && env
            secret_val = LotusRunner.secret_get(env, k)
            results << { path: (path + [k]).join('.'), key: k, value: secret_val }
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
            secret_val = LotusRunner.secret_get(env, v)
            results << { path: (path + [i]).join('.'), key: v, value: secret_val }
          else
            results << { path: (path + [i]).join('.'), key: v, value: '{SECRET}' }
          end
        end
      end
    end
    results
  end
end
