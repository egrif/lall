# frozen_string_literal: true

# lib/lall/table_formatter.rb
class TableFormatter
  # ANSI color codes
  COLORS = {
    white: "\e[37m",    # Environment value only
    yellow: "\e[33m",   # Environment overrides group
    green: "\e[32m",    # Group value, no override
    blue: "\e[34m",     # Group value same as override
    reset: "\e[0m"      # Reset color
  }.freeze

  def initialize(columns, envs, env_results, options)
    @columns = columns
    @envs = envs
    @env_results = env_results
    @options = options
    @truncate = options[:truncate]
    @path_also = options[:path_also]
    @env_width = ['Env'.length, *envs.map(&:length)].max
  end

  def colorize_value(value_str, color_type)
    return value_str if color_type.nil? || !$stdout.tty?

    "#{COLORS[color_type]}#{value_str}#{COLORS[:reset]}"
  end

  def calculate_display_width(text)
    # Remove ANSI color codes when calculating width
    text.gsub(/\e\[[0-9;]*m/, '').length
  end

  def compute_col_widths
    if @path_also
      compute_path_key_col_widths
    else
      compute_key_col_widths
    end
  end

  def compute_path_key_col_widths
    @columns.map do |col|
      header_str = "#{col[:path]}.#{col[:key]}"
      max_data_width = calculate_max_data_width_for_path_key(col, header_str)
      [header_str.length, max_data_width].max
    end
  end

  def compute_key_col_widths
    @columns.map do |k|
      header_str = k.to_s
      max_data_width = calculate_max_data_width_for_key(k, header_str)
      [header_str.length, max_data_width].max
    end
  end

  def calculate_max_data_width_for_path_key(col, header_str)
    @envs.map do |env|
      match = @env_results[env].find { |r| r[:path] == col[:path] && r[:key] == col[:key] }
      calculate_value_width(match, header_str)
    end.max
  end

  def calculate_max_data_width_for_key(key, header_str)
    @envs.map do |env|
      match = @env_results[env].find { |r| r[:key] == key }
      calculate_value_width(match, header_str)
    end.max
  end

  def calculate_value_width(match, header_str)
    value_str = extract_value_string(match)
    trunc_len = @truncate ? [@truncate, header_str.length].max : nil

    if trunc_len
      [header_str.length, TableFormatter.truncate_middle(value_str, trunc_len).length].max
    else
      [header_str.length, value_str.length].max
    end
  end

  def extract_value_string(match)
    if match
      match[:value].is_a?(String) ? match[:value] : match[:value].inspect
    else
      ''
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
      row = format("| %-#{@env_width}s |", env)
      row += build_table_row_columns(env, col_widths)
      puts row
    end
  end

  private

  def build_table_row_columns(env, col_widths)
    row_columns = ''
    if @path_also
      @columns.each_with_index do |col, i|
        match = @env_results[env].find { |r| r[:path] == col[:path] && r[:key] == col[:key] }
        row_columns += format_table_cell(match, col_widths[i])
      end
    else
      @columns.each_with_index do |k, i|
        match = @env_results[env].find { |r| r[:key] == k }
        row_columns += format_table_cell(match, col_widths[i])
      end
    end
    row_columns
  end

  def format_table_cell(match, col_width)
    value_str = if match
                  match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                else
                  ''
                end
    value_str = TableFormatter.truncate_middle(value_str, col_width) if @truncate
    colored_value_str = colorize_value(value_str, match&.[](:color))
    display_width = calculate_display_width(colored_value_str)
    padding = col_width - display_width
    " #{colored_value_str}#{' ' * [padding, 0].max} |"
  end

  public

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
    envs.each_with_index { |env, i| header += format(" %-#{env_widths[i]}s |", env) }
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
          colored_value_str = colorize_value(value_str, match&.[](:color))
          display_width = calculate_display_width(colored_value_str)
          padding = env_widths[i] - display_width
          row += " #{colored_value_str}#{' ' * [padding, 0].max} |"
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
    envs.each_with_index { |env, i| header += format(" %-#{env_widths[i]}s |", env) }
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
        colored_value_str = colorize_value(value_str, match&.[](:color))
        display_width = calculate_display_width(colored_value_str)
        padding = env_widths[i] - display_width
        row += " #{colored_value_str}#{' ' * [padding, 0].max} |"
      end
      # Only print rows where at least one env has a value
      puts row unless envs.all? { |env| env_results[env].none? { |r| r[:key] == key } }
    end
  end
end
