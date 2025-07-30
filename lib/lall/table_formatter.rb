# frozen_string_literal: true

# lib/lall/table_formatter.rb
class TableFormatter
  def initialize(columns, envs, env_results, options)
    @columns = columns
    @envs = envs
    @env_results = env_results
    @options = options
    @truncate = options[:truncate]
    @path_also = options[:path_also]
    @env_width = ['Env'.length, *envs.map(&:length)].max
  end

  def compute_col_widths
    if @path_also
      @columns.map do |col|
        header_str = "#{col[:path]}.#{col[:key]}"
        max_data = @envs.map do |env|
          match = @env_results[env].find { |r| r[:path] == col[:path] && r[:key] == col[:key] }
          value_str = if match
                        match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                      else
                        ''
                      end
          trunc_len = @truncate ? [@truncate, header_str.length].max : nil
          if trunc_len
            [header_str.length,
             TableFormatter.truncate_middle(value_str,
                                            trunc_len).length].max
          else
            [header_str.length, value_str.length].max
          end
        end.max
        [header_str.length, max_data].max
      end
    else
      @columns.map do |k|
        header_str = k.to_s
        max_data = @envs.map do |env|
          match = @env_results[env].find { |r| r[:key] == k }
          value_str = if match
                        match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                      else
                        ''
                      end
          trunc_len = @truncate ? [@truncate, header_str.length].max : nil
          if trunc_len
            [header_str.length,
             TableFormatter.truncate_middle(value_str,
                                            trunc_len).length].max
          else
            [header_str.length, value_str.length].max
          end
        end.max
        [header_str.length, max_data].max
      end
    end
  end

  def self.truncate_middle(str, max_len)
    return str if str.length <= max_len
    return str if max_len < 5

    half = (max_len - 3) / 2
    first = str[0, half]
    last = str[-half, half]
    "#{first}...#{last}"
  end

  def build_header(col_widths)
    header = format("| %-#{@env_width}s |", 'Env')
    if @path_also
      @columns.each_with_index do |col, i|
        header += format(" %-#{col_widths[i]}s |", "#{col[:path]}.#{col[:key]}")
      end
    else
      @columns.each_with_index do |k, i|
        header += format(" %-#{col_widths[i]}s |", k.to_s)
      end
    end
    header
  end

  def print_table
    col_widths = compute_col_widths
    puts build_header(col_widths)
    sep = "|-#{'-' * @env_width}-|"
    @columns.each_with_index { |_, i| sep += "-#{'-' * col_widths[i]}-|" }
    puts sep
    @envs.each do |env|
      row = "| %-#{@env_width}s |" % env
      if @path_also
        @columns.each_with_index do |col, i|
          match = @env_results[env].find { |r| r[:path] == col[:path] && r[:key] == col[:key] }
          value_str = if match
                        match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                      else
                        ''
                      end
          value_str = TableFormatter.truncate_middle(value_str, col_widths[i]) if @truncate
          row += " %-#{col_widths[i]}s |" % value_str
        end
      else
        @columns.each_with_index do |k, i|
          match = @env_results[env].find { |r| r[:key] == k }
          value_str = if match
                        match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                      else
                        ''
                      end
          value_str = TableFormatter.truncate_middle(value_str, col_widths[i]) if @truncate
          row += " %-#{col_widths[i]}s |" % value_str
        end
      end
      puts row
    end
  end

  def print_path_table(all_paths, all_keys, envs, env_results)
    path_width = ['Path'.length, *all_paths.map(&:length)].max
    key_width = ['Key'.length, *all_keys.map(&:length)].max
    env_widths = envs.map do |env|
      [env.length, *env_results[env].map do |r|
        (r[:value].is_a?(String) ? r[:value] : r[:value].inspect).length
      end].max
    end

    # Header
    header = format("| %-#{path_width}s | %-#{key_width}s |", 'Path', 'Key')
    envs.each_with_index { |env, i| header += " %-#{env_widths[i]}s |" % env }
    puts header
    sep = "|-#{'-' * path_width}-|-#{'-' * key_width}-|"
    envs.each_with_index { |_, i| sep += "-#{'-' * env_widths[i]}-|" }
    puts sep

    all_paths.each do |path|
      all_keys.each do |key|
        row = format("| %-#{path_width}s | %-#{key_width}s |", path, key)
        envs.each_with_index do |env, i|
          match = env_results[env].find { |r| r[:path] == path && r[:key] == key }
          value_str = if match
                        match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                      else
                        ''
                      end
          value_str = TableFormatter.truncate_middle(value_str, @options[:truncate]) if @options[:truncate]
          row += " %-#{env_widths[i]}s |" % value_str
        end
        # Only print rows where at least one env has a value
        puts row unless envs.all? { |env| env_results[env].none? { |r| r[:path] == path && r[:key] == key } }
      end
    end
  end

  def print_key_table(all_keys, envs, env_results)
    key_width = ['Key'.length, *all_keys.map(&:length)].max
    env_widths = envs.map do |env|
      [env.length, *env_results[env].map do |r|
        (r[:value].is_a?(String) ? r[:value] : r[:value].inspect).length
      end].max
    end

    # Header
    header = format("| %-#{key_width}s |", 'Key')
    envs.each_with_index { |env, i| header += " %-#{env_widths[i]}s |" % env }
    puts header
    sep = "|-#{'-' * key_width}-|"
    envs.each_with_index { |_, i| sep += "-#{'-' * env_widths[i]}-|" }
    puts sep

    all_keys.each do |key|
      row = format("| %-#{key_width}s |", key)
      envs.each_with_index do |env, i|
        match = env_results[env].find { |r| r[:key] == key }
        value_str = if match
                      match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                    else
                      ''
                    end
        value_str = TableFormatter.truncate_middle(value_str, @options[:truncate]) if @options[:truncate]
        row += " %-#{env_widths[i]}s |" % value_str
      end
      # Only print rows where at least one env has a value
      puts row unless envs.all? { |env| env_results[env].none? { |r| r[:key] == key } }
    end
  end
end
