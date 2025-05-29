# lib/lall/key_searcher.rb
class KeySearcher
  def self.search(obj, search_str, path = [], results = [], insensitive = false)
    case obj
    when Hash
      obj.each do |k, v|
        key_str = k.to_s
        match = insensitive ? key_str.downcase.include?(search_str.downcase) : key_str.include?(search_str)
        if match
          results << { path: (path + [k]).join('.'), key: k, value: v }
        end
        search(v, search_str, path + [k], results, insensitive)
      end
    when Array
      obj.each_with_index do |v, i|
        search(v, search_str, path + [i], results, insensitive)
      end
    end
    results
  end
end
