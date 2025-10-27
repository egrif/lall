# frozen_string_literal: true

# lib/lall/table_formatter.rb
class TableFormatter
  # ANSI color codes
  COLORS = {
    white: "\e[37m",
    yellow: "\e[33m",
    green: "\e[32m",
    blue: "\e[34m",
    red: "\e[31m",
    cyan: "\e[36m",
    magenta: "\e[35m",
    black: "\e[30m",
    reset: "\e[0m"
  }.freeze

  def initialize(columns, envs, env_results, options, settings = nil)
    @columns = columns
    @envs = envs
    @env_results = env_results
    @options = options
    @settings = settings
    @truncate = options[:truncate]
    @path_also = options[:path_also]
    @env_width = ['Env'.length, *envs.map(&:length)].max
  end

  def colorize_value(value_str, color_type)
    return value_str if color_type.nil? || !$stdout.tty?

    # Get color name from settings if available, fallback to hardcoded mapping
    color_name = if @settings
                   @settings.get("output.colors.#{color_type}", color_type)
                 else
                   color_type
                 end

    # Convert color name to symbol if it's a string
    color_name = color_name.to_sym if color_name.is_a?(String)

    # Get color codes from settings color_reference or fallback to hardcoded COLORS
    color_code = if @settings
                   @settings.get("color_reference.#{color_name}", COLORS[color_name])
                 else
                   COLORS[color_name]
                 end

    reset_code = if @settings
                   @settings.get('color_reference.reset', COLORS[:reset])
                 else
                   COLORS[:reset]
                 end

    "#{color_code}#{value_str}#{reset_code}"
  end

  def calculate_display_width(text)
    # Remove ANSI color codes when calculating width
    clean_text = text.gsub(/\e\[[0-9;]*m/, '')

    # Calculate actual display width accounting for wide characters (emojis, etc.)
    display_width = 0
    clean_text.each_char do |char|
      # Wide characters (including emojis) typically take 2 columns
      # This includes most emojis, CJK characters, etc.
      display_width += if (char.ord > 0x1F600 && char.ord < 0x1F64F) ||  # Emoticons
                          (char.ord > 0x1F300 && char.ord < 0x1F5FF) ||  # Misc Symbols and Pictographs
                          (char.ord > 0x1F680 && char.ord < 0x1F6FF) ||  # Transport and Map
                          (char.ord > 0x2600 && char.ord < 0x26FF) ||    # Misc symbols
                          (char.ord > 0x2700 && char.ord < 0x27BF) ||    # Dingbats
                          (char.ord > 0x1F900 && char.ord < 0x1F9FF)     # Supplemental Symbols and Pictographs
                         2
                       else
                         1
                       end
    end

    display_width
  end

  def pad_string_to_width(text, target_width)
    actual_width = calculate_display_width(text)
    padding_needed = target_width - actual_width
    padding_needed = 0 if padding_needed.negative?
    "#{text}#{' ' * padding_needed}"
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
      [calculate_display_width(header_str), max_data_width].max
    end
  end

  def compute_key_col_widths
    @columns.map do |k|
      header_str = k.to_s
      max_data_width = calculate_max_data_width_for_key(k, header_str)
      [calculate_display_width(header_str), max_data_width].max
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
    header_display_width = calculate_display_width(header_str)
    trunc_len = @truncate&.positive? ? [@truncate, header_display_width].max : nil

    if trunc_len
      [header_display_width, calculate_display_width(TableFormatter.truncate_middle(value_str, trunc_len))].max
    else
      [header_display_width, calculate_display_width(value_str)].max
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
    header = "| #{pad_string_to_width('Env', @env_width)} |"
    if @path_also
      @columns.each_with_index do |col, i|
        col_text = "#{col[:path]}.#{col[:key]}"
        header += " #{pad_string_to_width(col_text, col_widths[i])} |"
      end
    else
      @columns.each_with_index do |k, i|
        header += " #{pad_string_to_width(k.to_s, col_widths[i])} |"
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
      row = "| #{pad_string_to_width(env, @env_width)} |"
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
    value_str = TableFormatter.truncate_middle(value_str, col_width) if @truncate&.positive?
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
      max_value_width = env_results[env].map do |r|
        value_str = r[:value].is_a?(String) ? r[:value] : r[:value].inspect
        if @truncate&.positive?
          TableFormatter.truncate_middle(value_str, @truncate).length
        else
          value_str.length
        end
      end.max || 0
      [env.length, max_value_width].max
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
          value_str = TableFormatter.truncate_middle(value_str, @truncate) if @truncate&.positive?
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
    key_width = ['Key'.length, *all_keys.map { |k| calculate_display_width(k) }].max
    env_widths = envs.map do |env|
      max_value_width = env_results[env].map do |r|
        value_str = r[:value].is_a?(String) ? r[:value] : r[:value].inspect
        if @truncate&.positive?
          TableFormatter.truncate_middle(value_str, @truncate).length
        else
          value_str.length
        end
      end.max || 0
      [env.length, max_value_width].max
    end

    # Header
    header = "| #{pad_string_to_width('Key', key_width)} |"
    envs.each_with_index { |env, i| header += " #{pad_string_to_width(env, env_widths[i])} |" }
    puts header
    sep = "|-#{'-' * key_width}-|"
    envs.each_with_index { |_, i| sep += "-#{'-' * env_widths[i]}-|" }
    puts sep

    all_keys.each do |key|
      row = "| #{pad_string_to_width(key, key_width)} |"
      envs.each_with_index do |env, i|
        match = env_results[env].find { |r| r[:key] == key }
        value_str = if match
                      match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                    else
                      ''
                    end
        value_str = TableFormatter.truncate_middle(value_str, @truncate) if @truncate&.positive?
        colored_value_str = colorize_value(value_str, match&.[](:color))
        display_width = calculate_display_width(colored_value_str)
        padding = env_widths[i] - display_width
        row += " #{colored_value_str}#{' ' * [padding, 0].max} |"
      end
      # Only print rows where at least one env has a value
      puts row unless envs.all? { |env| env_results[env].none? { |r| r[:key] == key } }
    end
  end

  def print_keyvalue_format(envs, env_results)
    envs.each do |env|
      # Build environment header - extract space and region from env if possible  
      env_header = build_environment_header(env)
      puts "#{env_header}:"
      
      # Get all results for this environment and sort by key
      env_matches = env_results[env] || []
      env_matches.sort_by { |match| match[:key] }.each do |match|
        value_str = if match[:value]
                      match[:value].is_a?(String) ? match[:value] : match[:value].inspect
                    else
                      ''
                    end
        
        # Apply truncation if specified
        value_str = TableFormatter.truncate_middle(value_str, @truncate) if @truncate&.positive?
        
        # Apply color formatting
        colored_value_str = colorize_value(value_str, match&.[](:color))
        
        puts "  #{match[:key]}: '#{colored_value_str}'"
      end
      
      # Add blank line between environments unless this is the last one
      puts "" unless env == envs.last
    end
  end

  private

  def build_environment_header(env)
    # Try to extract space/region info from environment name patterns
    # Format: ENV/SPACE/REGION
    
    # Check if env has space/region info embedded (basic heuristic)
    # This is a simplified approach - in a real scenario, we'd want access to the Environment object
    if env.include?(':')
      # Format like "env:space:region"
      parts = env.split(':')
      case parts.length
      when 3
        "#{parts[0]}/#{parts[1]}/#{parts[2]}"
      when 2  
        "#{parts[0]}/#{parts[1]}"
      else
        env
      end
    elsif env.match(/^(\w+)-s(\d+)$/)
      # Format like "prod-s101" -> extract region based on suffix
      base_env = $1
      suffix = $2.to_i
      region = case suffix
               when 1..99 then 'use1'
               when 101..199 then 'euc1'
               when 201..299 then 'apse2'
               else 'unknown'
               end
      "#{base_env}/prod/#{region}"
    else
      # Default format - just use env name, could be enhanced with space/region from settings
      env
    end
  end
end
