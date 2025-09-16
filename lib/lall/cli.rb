# frozen_string_literal: true

# lib/lall/cli.rb
require 'optparse'
require 'yaml'
require 'lotus/runner'
require 'lotus/entity'
require 'lotus/environment'
require 'lotus/group'
require_relative 'table_formatter'
require_relative 'cache_manager'
require_relative 'settings_manager'
require_relative 'null_cache_manager'
require_relative 'version'
require_relative '../lotus/entity_set'

# Keep legacy constants for backward compatibility
SETTINGS_PATH = File.expand_path('../../config/settings.yml', __dir__)
SETTINGS = YAML.load_file(SETTINGS_PATH) if File.exist?(SETTINGS_PATH)
ENV_GROUPS = SETTINGS ? SETTINGS['groups'] : {}

class LallCLI
  def initialize(argv)
    @raw_options = {}
    setup_option_parser.parse!(argv)

    # Initialize singleton settings manager with CLI options
    @settings = Lall::SettingsManager.instance(@raw_options)

    # Resolve final options using settings priority
    @options = resolve_all_options

    initialize_cache_manager
  end

  # TODO: Env definitions
  # 1. accept env:space:region,env:space:region...
  # 2. accept -s space -r region -a application as override for anything else not specified on the command line

  private

  def setup_option_parser
    OptionParser.new do |opts|
      opts.banner = 'Usage: ruby lall -m MATCH [-e ENV[,ENV2,...]] [-g GROUP] [-p] [-i] [-v]'
      setup_search_options(opts)
      setup_environment_options(opts)
      setup_format_options(opts)
      setup_behavior_options(opts)
    end
  end

  def setup_search_options(opts)
    opts.on('-mMATCH', '--match=MATCH', 'Glob pattern to search for in YAML keys (required)') do |v|
      @raw_options[:match] = v
    end
    opts.on('-i', '--insensitive', 'Case-insensitive key search (optional)') { @raw_options[:insensitive] = true }
  end

  def setup_environment_options(opts)
    opts.on('-eENV', '--env=ENV',
            'Comma-separated environment(s) to search, e.g., "prod,staging:prod,prod-s5:prod:use1"') do |v|
      @raw_options[:env] = v
    end
    opts.on('-gGROUP', '--group=GROUP',
            'Group name to use a related list of environments (mutually exclusive with -e)',
            'Use "list" to see available groups') do |v|
      @raw_options[:group] = v
    end

    opts.on('-sSPACE', '--space=SPACE', 'Default space for environments') do |v|
      @raw_options[:space] = v
    end
    opts.on('-aAPP', '--application=APP', 'Default application for environments') do |v|
      @raw_options[:application] = v
    end
    opts.on('-rREGION', '--region=REGION', 'Default region for environments') do |v|
      @raw_options[:region] = v
    end
  end

  def setup_format_options(opts)
    opts.on('-p', '--path', 'Include the path column in the output table (optional)') do
      @raw_options[:path_also] = true
    end
    opts.on('-v', '--pivot', 'Pivot the table so environments are rows and keys/paths are columns (optional)') do
      @raw_options[:pivot] = true
    end
    opts.on('-t LEN', '--truncate=LEN', Integer,
            'Truncate output values longer than LEN (default 40) with ellipsis in the middle') do |v|
      @raw_options[:truncate] = v
    end
  end

  def setup_behavior_options(opts)
    opts.on('--version', 'Show version and exit') do
      puts "lall #{Lall::VERSION}"
      exit
    end
    opts.on('-x', '--expose', 'Expose secrets (show actual secret values for secrets/group_secrets keys)') do
      @raw_options[:expose] = true
    end
    opts.on('-d', '--debug', 'Enable debug output (prints lotus commands)') { @raw_options[:debug] = true }
    opts.on('--debug-settings', 'Show settings resolution and exit') { @raw_options[:debug_settings] = true }
    opts.on('--show-settings', 'Show all resolved settings and exit') { @raw_options[:show_settings] = true }
    opts.on('--init-settings', 'Initialize user settings file and exit') { @raw_options[:init_settings] = true }
    setup_cache_options(opts)
  end

  def setup_cache_options(opts)
    opts.on('--cache-ttl=SECONDS', Integer, 'Cache TTL in seconds (default: 3600)') do |v|
      @raw_options[:cache_ttl] = v
    end
    opts.on('--cache-dir=DIR', 'Cache directory for disk storage (default: ~/.lall/cache)') do |v|
      @raw_options[:cache_dir] = v
    end
    opts.on('--cache-prefix=PREFIX', 'Cache key prefix (default: lall-cache)') do |v|
      @raw_options[:cache_prefix] = v
    end
    opts.on('--no-cache', 'Disable caching') { @raw_options[:cache_enabled] = false }
    opts.on('--clear-cache', 'Clear cache and exit') { @raw_options[:clear_cache] = true }
    opts.on('--cache-stats', 'Show cache statistics and exit') { @raw_options[:cache_stats] = true }
  end

  # Resolve all options using the settings priority system
  def resolve_all_options
    resolved = {}

    resolve_core_options(resolved)
    resolve_cli_behavior_options(resolved)
    resolve_cache_options(resolved)
    resolve_special_commands(resolved)

    resolved
  end

  public

  def run
    # Initialize cache manager
    initialize_cache_manager

    # Handle debug settings command
    if @raw_options[:debug_settings]
      @settings.debug_settings
      return
    end

    # Handle show settings command
    if @raw_options[:show_settings]
      show_all_settings
      return
    end

    # Handle init settings command
    init_user_settings_and_exit if @raw_options[:init_settings]

    # Handle cache-specific commands
    if @options[:clear_cache]
      clear_cache_and_exit
    elsif @options[:cache_stats]
      show_cache_stats_and_exit
    end

    # Handle special case: -g list
    if @options[:group] == 'list'
      print_available_groups
      return
    end

    validate_options

    # Use EntitySet for environment fetching and instantiation
    entity_set = create_entity_set
    entity_set.fetch_all

    env_results = fetch_results_from_entity_set(entity_set)
    # Only pass environments that have results (excludes failed environments)
    successful_envs = env_results.keys
    display_results(successful_envs, env_results)
  end

  def create_entity_set
    require_relative '../lotus/entity_set'
    Lotus::EntitySet.new(@settings)
  end

  def fetch_results_from_entity_set(entity_set)
    env_results = {}

    # Entity data should already be loaded by fetch_all in run method
    entity_set.environments.each do |env|
      # Skip environments that failed to load data
      next unless env.data

      # Build search data in the format expected by KeySearcher
      search_data = build_search_data_for_entity(env, entity_set)

      # Perform search using the constructed search data
      result = perform_search(search_data, env.name)
      env_results[env.name] = result
    end

    env_results
  end

  def build_search_data_for_entity(env, entity_set)
    search_data = {}

    # Skip if environment data failed to load
    return search_data unless env.data

    # Add configs from environment
    search_data['configs'] = env.configs if env.configs

    # Add secrets from environment (if expose is enabled, fetch secret values)
    if env.secrets && !env.secrets.empty?
      search_data['secrets'] = {}
      if @options[:expose]
        # Get secret values from the instantiated secret objects
        env.secrets.each do |secret|
          search_data['secrets'][secret.name] = secret.data
        end
        # Also maintain the keys array for KeySearcher compatibility
      end
      # Just store the secret keys for pattern matching
      search_data['secrets']['keys'] = env.secrets.map(&:name)
    end

    # Add group secrets (find the group for this environment)
    if env.group_name
      group = entity_set.groups.find { |g| g.name == env.group_name }
      add_group_data_to_search_data(search_data, group) if group&.data
    end

    search_data
  end

  def add_group_data_to_search_data(search_data, group)
    # Add group configs for color comparison
    group_configs = group.configs
    search_data['group_configs'] = group_configs if group_configs && !group_configs.empty?

    # Add group secrets
    group_secrets = group.secrets
    return unless group_secrets && !group_secrets.empty?

    search_data['group_secrets'] = {}
    if @options[:expose]
      # Get group secret values from the instantiated secret objects
      group_secrets.each do |secret|
        search_data['group_secrets'][secret.name] = secret.data
      end
    else
      # Just store the group secret keys for pattern matching
      search_data['group_secrets']['keys'] = group_secrets.map(&:name)
    end
  rescue NoMethodError
    # Group data failed to load, skip group data
  end

  def resolve_core_options(resolved)
    # Core search options (CLI-only, no settings fallback)
    resolved[:match] = @raw_options[:match]
    resolved[:env] = @raw_options[:env]
    resolved[:group] = @raw_options[:group]
  end

  def resolve_cli_behavior_options(resolved)
    # CLI behavior options (with settings fallback)
    cli_settings = @settings.cli_settings
    resolved[:debug] = @raw_options[:debug] || cli_settings[:debug]
    resolved[:truncate] = @raw_options[:truncate] || cli_settings[:truncate]
    resolved[:expose] = @raw_options[:expose] || cli_settings[:expose]
    resolved[:insensitive] = @raw_options[:insensitive] || cli_settings[:insensitive]
    resolved[:path_also] = @raw_options[:path_also] || cli_settings[:path_also]
    resolved[:pivot] = @raw_options[:pivot] || cli_settings[:pivot]
  end

  def resolve_cache_options(resolved)
    # Cache options (with settings fallback)
    cache_settings = @settings.cache_settings
    resolved[:cache_ttl] = @raw_options[:cache_ttl] || cache_settings[:ttl]
    resolved[:cache_dir] = @raw_options[:cache_dir] || cache_settings[:directory]
    resolved[:cache_prefix] = @raw_options[:cache_prefix] || cache_settings[:prefix]
    resolved[:cache_enabled] =
      @raw_options.key?(:cache_enabled) ? @raw_options[:cache_enabled] : cache_settings[:enabled]
  end

  def resolve_special_commands(resolved)
    # Special cache commands (CLI-only)
    resolved[:clear_cache] = @raw_options[:clear_cache]
    resolved[:cache_stats] = @raw_options[:cache_stats]
    resolved[:debug_settings] = @raw_options[:debug_settings]
    resolved[:show_settings] = @raw_options[:show_settings]
    resolved[:init_settings] = @raw_options[:init_settings]
  end

  def print_available_groups
    puts 'Available groups:'
    @settings.groups.each do |group_name, environments|
      puts "  #{group_name}: #{environments.join(', ')}"
    end
  end

  def initialize_cache_manager
    # Use settings manager for cache configuration
    cache_settings = @settings.cache_settings

    cache_options = {
      enabled: @options[:cache_enabled],
      ttl: @options[:cache_ttl],
      cache_dir: @options[:cache_dir],
      cache_prefix: @options[:cache_prefix],
      redis_url: cache_settings[:redis_url]
    }

    @cache_manager = if cache_options[:enabled] == false
                       Lall::NullCacheManager.new
                     else
                       Lall::CacheManager.instance(cache_options)
                     end
  rescue StandardError => e
    warn "Warning: Cache initialization failed (#{e.message}). Disabling cache."
    @cache_manager = Lall::NullCacheManager.new
  end

  def clear_cache_and_exit
    if @cache_manager.clear_cache
      puts 'Cache cleared successfully.'
    else
      puts 'Failed to clear cache.'
    end
    exit 0
  end

  def show_cache_stats_and_exit
    stats = @cache_manager.stats
    puts 'Cache Statistics:'
    display_basic_cache_stats(stats)
    display_cache_size_stats(stats)
    exit 0
  end

  def display_basic_cache_stats(stats)
    puts "  Backend: #{stats[:backend]}"
    puts "  Enabled: #{stats[:enabled]}"
    puts "  TTL: #{stats[:ttl]} seconds"
    puts "  Prefix: #{stats[:cache_prefix]}"
    puts "  Cache Dir: #{stats[:cache_dir]}" if stats[:cache_dir]
    puts "  Redis URL: #{stats[:redis_url]}" if stats[:redis_url]
  end

  def display_cache_size_stats(stats)
    return unless stats[:cache_size]

    cache_size = stats[:cache_size]
    puts '  Cache Size:'
    puts "    Total Keys: #{cache_size[:total_keys]}"
    puts "    Prefixed Keys: #{cache_size[:prefixed_keys]}"
    puts "    Total Size: #{format_bytes(cache_size[:total_size_bytes])}"

    # Display entity counts if available
    return unless stats[:entity_counts]

    entity_counts = stats[:entity_counts]
    puts '  Cached Entities:'
    puts "    Environments: #{entity_counts[:environments]}"
    puts "    Groups: #{entity_counts[:groups]}"
    puts "    Environment Secrets: #{entity_counts[:env_secrets]}"
    puts "    Group Secrets: #{entity_counts[:group_secrets]}"
  end

  def format_bytes(bytes)
    return '0 B' if bytes.zero?

    units = %w[B KB MB GB TB]
    size = bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024.0
      unit_index += 1
    end

    format('%<size>.1f %<unit>s', size: size, unit: units[unit_index])
  end

  def show_all_settings
    puts 'All Resolved Settings:'
    puts '======================'
    puts ''

    # Core search options
    puts 'Search Options:'
    puts "  match: #{@options[:match] || 'not set'}"
    puts "  env: #{@options[:env] || 'not set'}"
    puts "  group: #{@options[:group] || 'not set'}"
    puts "  insensitive: #{@options[:insensitive]}"
    puts ''

    # Output options
    puts 'Output Options:'
    puts "  path_also: #{@options[:path_also]}"
    puts "  pivot: #{@options[:pivot]}"
    puts "  truncate: #{@options[:truncate]}"
    puts "  expose: #{@options[:expose]}"
    puts "  debug: #{@options[:debug]}"
    puts "  secret_placeholder: #{@settings.get('output.secret_placeholder', '{SECRET}')}"
    puts ''

    # Color settings
    puts 'Color Settings:'
    puts "  from_env: #{@settings.get('output.colors.from_env', :white)}"
    puts "  from_group: #{@settings.get('output.colors.from_group', :blue)}"
    puts "  env_changes_group: #{@settings.get('output.colors.env_changes_group', :yellow)}"
    puts "  env_mirrors_group: #{@settings.get('output.colors.env_mirrors_group', :green)}"
    puts ''

    # Cache settings
    cache_settings = @settings.cache_settings
    puts 'Cache Settings:'
    puts "  enabled: #{cache_settings[:enabled]}"
    puts "  backend: #{cache_settings[:backend] || 'auto-detect'}"
    puts "  ttl: #{cache_settings[:ttl]} seconds"
    puts "  cache_prefix: #{cache_settings[:cache_prefix] || 'lall-cache'}"
    puts "  cache_dir: #{cache_settings[:cache_dir] || '~/.lall/cache'}"
    puts "  redis_url: #{cache_settings[:redis_url] || 'not set'}"
    puts "  secret_ttl: #{cache_settings[:secret_ttl] || cache_settings[:ttl]} seconds"
    puts ''

    # Groups
    groups = @settings.groups
    puts 'Available Groups:'
    if groups.empty?
      puts '  (none defined)'
    else
      groups.each do |name, envs|
        puts "  #{name}: #{envs.join(', ')}"
      end
    end
    puts ''

    # Settings sources information
    puts 'Settings Sources (in priority order):'
    puts '  1. CLI arguments'
    puts '  2. Environment variables'
    puts "  3. User settings: #{@settings.class::USER_SETTINGS_PATH}"
    puts "  4. Gem defaults: #{@settings.class::GEM_SETTINGS_PATH}"
    puts ''
    puts "Use 'lall --debug-settings' for detailed resolution information."

    exit 0
  end

  def init_user_settings_and_exit
    settings_path = Lall::SettingsManager::USER_SETTINGS_PATH

    if File.exist?(settings_path)
      puts "Settings file already exists at: #{settings_path}"
      puts 'To recreate it, delete the existing file first.'
      exit 1
    end

    @settings.ensure_user_settings_exist
    puts "✅ Created user settings file at: #{settings_path}"
    puts ''
    puts 'You can now customize your default settings by editing this file.'
    puts 'Examples:'
    puts '  - Set default cache TTL: cache.ttl: 7200'
    puts '  - Set default truncation: output.truncate: 100'
    puts '  - Enable debug by default: output.debug: true'
    puts ''
    puts "Run 'lall --debug-settings' to see how settings are resolved."
    exit 0
  end

  def validate_options
    return if valid_option_combination?

    puts 'Usage: ruby lall -m MATCH [-e ENV[,ENV2,...]] [-g GROUP] [-p]'
    puts '  -e and -g are mutually exclusive and one is required.'
    exit 1
  end

  def valid_option_combination?
    # Special case: allow -g list without match requirement
    return true if @options[:group] == 'list'

    # Check for mutually exclusive options first
    return false if @options[:env] && @options[:group]

    # Check for unknown group after mutual exclusion check
    if @options[:group] && @options[:group] != 'list' && !@settings.groups[@options[:group]]
      puts("Unknown group: #{@options[:group]}")
      exit 1
    end

    @options[:match] &&
      (@options[:env] || @options[:group])
  end

  def display_results(envs, env_results)
    all_keys = extract_all_keys(env_results)
    all_paths = extract_all_paths(env_results)

    if all_keys.empty?
      puts "No keys found matching '#{@options[:match]}'."
      return
    end

    format_and_display_table(envs, env_results, all_keys, all_paths)
  end

  def extract_all_keys(env_results)
    env_results.values.flatten.map { |r| r[:key] }.uniq
  end

  def extract_all_paths(env_results)
    env_results.values.flatten.map { |r| r[:path] }.uniq
  end

  def format_and_display_table(envs, env_results, all_keys, all_paths)
    if @options[:pivot]
      display_pivot_table(envs, env_results, all_keys, all_paths)
    elsif @options[:path_also]
      TableFormatter.new([], envs, env_results, @options, @settings).print_path_table(all_paths, all_keys, envs,
                                                                                      env_results)
    else
      TableFormatter.new([], envs, env_results, @options, @settings).print_key_table(all_keys, envs, env_results)
    end
  end

  def display_pivot_table(envs, env_results, all_keys, all_paths)
    columns = if @options[:path_also]
                all_paths.product(all_keys).map { |p, k| { path: p, key: k } }
              else
                all_keys
              end
    TableFormatter.new(columns, envs, env_results, @options, @settings).print_table
  end

  def perform_search(search_data, _env)
    # Simple search that just shows secret placeholder for secrets instead of KeySearcher
    results = []
    pattern = @options[:match]

    # Search configs with intelligent coloring
    search_data['configs']&.each do |key, value|
      next unless key_matches_pattern?(key, pattern)

      # Determine color based on whether this value exists in group configs
      color = determine_config_color(key, value, search_data)
      results << { path: 'configs', key: key, value: value, color: color }
    end

    # Search secrets - show actual values if exposing, otherwise show placeholder
    if search_data['secrets'] && search_data['secrets']['keys']
      search_data['secrets']['keys'].each do |secret_key|
        next unless key_matches_pattern?(secret_key, pattern)

        value = if @options[:expose] && search_data['secrets'][secret_key]
                  search_data['secrets'][secret_key]
                else
                  @settings.get('output.secret_placeholder', '{SECRET}')
                end
        color = @settings.get('output.colors.from_env', :white)
        results << { path: 'secrets', key: secret_key, value: value, color: color }
      end
    end

    # Search group secrets - show actual values if exposing, otherwise show placeholder
    if search_data['group_secrets'] && search_data['group_secrets']['keys']
      search_data['group_secrets']['keys'].each do |secret_key|
        next unless key_matches_pattern?(secret_key, pattern)

        value = if @options[:expose] && search_data['group_secrets'][secret_key]
                  search_data['group_secrets'][secret_key]
                else
                  @settings.get('output.secret_placeholder', '{SECRET}')
                end
        color = @settings.get('output.colors.from_group', :green)
        results << { path: 'group_secrets', key: secret_key, value: value, color: color }
      end
    end

    results
  end

  # Determine the appropriate color for a config value based on group comparison
  def determine_config_color(key, env_value, search_data)
    # Check if there's a corresponding group config value
    group_configs = search_data['group_configs']
    return @settings.get('output.colors.from_env', :white) unless group_configs

    group_value = group_configs[key]
    return @settings.get('output.colors.from_env', :white) unless group_value

    # Compare environment value with group value
    if env_value == group_value
      @settings.get('output.colors.env_mirrors_group', :blue)
    else
      @settings.get('output.colors.env_changes_group', :yellow)
    end
  end

  def key_matches_pattern?(key, pattern)
    return true if pattern == '*' || pattern == key

    # Use case-insensitive matching if specified
    if @options[:insensitive]
      key.casecmp(pattern).zero? || File.fnmatch(pattern, key, File::FNM_CASEFOLD)
    else
      key == pattern || File.fnmatch(pattern, key)
    end
  rescue ArgumentError => e
    puts "Invalid pattern '#{pattern}': #{e.message}"
    false
  rescue StandardError => e
    warn "Error matching key '#{key}' with pattern '#{pattern}': #{e.message}"
    false
  end
end
