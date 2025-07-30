# frozen_string_literal: true

# lib/lall/cli.rb
require 'optparse'
require 'yaml'
require 'lotus/runner'
require 'lotus/environment'
require 'lotus/group'
require_relative 'key_searcher'
require_relative 'table_formatter'
require_relative 'cache_manager'

SETTINGS_PATH = File.expand_path('../../config/settings.yml', __dir__)
SETTINGS = YAML.load_file(SETTINGS_PATH)
ENV_GROUPS = SETTINGS['groups']

class LallCLI
  def initialize(argv)
    @options = {}
    setup_option_parser.parse!(argv)
    initialize_cache_manager
  end

  private

  def setup_option_parser
    OptionParser.new do |opts|
      opts.banner = 'Usage: ruby lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [-p] [-i] [-v]'
      setup_search_options(opts)
      setup_environment_options(opts)
      setup_format_options(opts)
      setup_behavior_options(opts)
    end
  end

  def setup_search_options(opts)
    opts.on('-sSTRING', '--string=STRING', 'String to search for in YAML keys (required)') do |v|
      @options[:string] = v
    end
    opts.on('-i', '--insensitive', 'Case-insensitive key search (optional)') { @options[:insensitive] = true }
  end

  def setup_environment_options(opts)
    opts.on('-eENV', '--env=ENV',
            'Comma-separated environment(s) to search, e.g., prod,stage (mutually exclusive with -g)') do |v|
      @options[:env] = v
    end
    opts.on('-gGROUP', '--group=GROUP',
            'Group name to use a related list of environments (mutually exclusive with -e)',
            'Use "list" to see available groups') do |v|
      @options[:group] = v
    end
  end

  def setup_format_options(opts)
    opts.on('-p', '--path', 'Include the path column in the output table (optional)') { @options[:path_also] = true }
    opts.on('-v', '--pivot', 'Pivot the table so environments are rows and keys/paths are columns (optional)') do
      @options[:pivot] = true
    end
    opts.on('-t[LEN]', '--truncate[=LEN]', Integer,
            'Truncate output values longer than LEN (default 40) with ellipsis in the middle') do |v|
      @options[:truncate] = v.nil? ? 40 : v
    end
  end

  def setup_behavior_options(opts)
    opts.on('-x', '--expose', 'Expose secrets (show actual secret values for secrets/group_secrets keys)') do
      @options[:expose] = true
    end
    opts.on('-d', '--debug', 'Enable debug output (prints lotus commands)') { @options[:debug] = true }
    setup_cache_options(opts)
  end

  def setup_cache_options(opts)
    opts.on('--cache-ttl=SECONDS', Integer, 'Cache TTL in seconds (default: 3600)') do |v|
      @options[:cache_ttl] = v
    end
    opts.on('--cache-dir=DIR', 'Cache directory for disk storage (default: ~/.lall/cache)') do |v|
      @options[:cache_dir] = v
    end
    opts.on('--no-cache', 'Disable caching') { @options[:cache_enabled] = false }
    opts.on('--clear-cache', 'Clear cache and exit') { @options[:clear_cache] = true }
    opts.on('--cache-stats', 'Show cache statistics and exit') { @options[:cache_stats] = true }
  end

  public

  def run
    # Initialize cache manager
    initialize_cache_manager

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
    envs = resolve_environments
    ping_environments(envs)
    env_results = fetch_env_results(envs)
    display_results(envs, env_results)
  end

  private

  def print_available_groups
    puts 'Available groups:'
    ENV_GROUPS.each do |group_name, environments|
      puts "  #{group_name}: #{environments.join(', ')}"
    end
  end

  def initialize_cache_manager
    cache_options = {
      ttl: @options[:cache_ttl],
      cache_dir: @options[:cache_dir],
      enabled: @options[:cache_enabled]
    }.compact

    begin
      @cache_manager = Lall::CacheManager.new(cache_options)
    rescue => e
      # If cache manager fails to initialize, create a null cache manager
      @cache_manager = NullCacheManager.new
      warn "Warning: Cache initialization failed: #{e.message}" if @options[:debug]
    end
  end

  # Null object pattern for cache manager
  class NullCacheManager
    def get(key, is_secret: false)
      nil
    end

    def set(key, value, is_secret: false)
      false
    end

    def delete(key)
      false
    end

    def clear
      false
    end

    def enabled?
      false
    end

    def stats
      { backend: 'disabled', enabled: false }
    end
  end

  def clear_cache_and_exit
    if @cache_manager.clear
      puts 'Cache cleared successfully.'
    else
      puts 'Failed to clear cache or caching is disabled.'
    end
    exit 0
  end

  def show_cache_stats_and_exit
    stats = @cache_manager.stats
    puts 'Cache Statistics:'
    puts "  Backend: #{stats[:backend]}"
    puts "  Enabled: #{stats[:enabled]}"
    puts "  TTL: #{stats[:ttl]} seconds"
    puts "  Cache Dir: #{stats[:cache_dir]}" if stats[:cache_dir]
    puts "  Redis URL: #{stats[:redis_url]}" if stats[:redis_url]
    exit 0
  end

  def validate_options
    return if valid_option_combination?

    puts 'Usage: ruby lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [-p]'
    puts '  -e and -g are mutually exclusive and one is required.'
    exit 1
  end

  def valid_option_combination?
    # Special case: allow -g list without string requirement
    return true if @options[:group] == 'list'

    @options[:string] &&
      (@options[:env] || @options[:group]) &&
      !(@options[:env] && @options[:group])
  end

  def resolve_environments
    if @options[:group]
      ENV_GROUPS[@options[:group]] || handle_unknown_group
    else
      @options[:env].split(',').map(&:strip)
    end
  end

  def handle_unknown_group
    puts("Unknown group: #{@options[:group]}")
    exit 1
  end

  def ping_environments(envs)
    s_args = envs.map { |env| Lotus::Runner.get_lotus_args(env).first }.uniq
    s_args.each { |s_arg| Lotus::Runner.ping(s_arg) }
  end

  def display_results(envs, env_results)
    all_keys = extract_all_keys(env_results)
    all_paths = extract_all_paths(env_results)

    if all_keys.empty?
      puts "No keys found containing '#{@options[:string]}'."
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
      TableFormatter.new([], envs, env_results, @options).print_path_table(all_paths, all_keys, envs, env_results)
    else
      TableFormatter.new([], envs, env_results, @options).print_key_table(all_keys, envs, env_results)
    end
  end

  def display_pivot_table(envs, env_results, all_keys, all_paths)
    columns = if @options[:path_also]
                all_paths.product(all_keys).map { |p, k| { path: p, key: k } }
              else
                all_keys
              end
    TableFormatter.new(columns, envs, env_results, @options).print_table
  end

  def fetch_env_results(envs)
    env_results = {}
    mutex = Mutex.new
    threads = create_search_threads(envs, env_results, mutex)
    threads.each(&:join)
    env_results
  end

  def create_search_threads(envs, env_results, mutex)
    envs.map do |env|
      Thread.new do
        search_data = extract_search_data(env)
        result = perform_search(search_data, env)
        mutex.synchronize { env_results[env] = result }
      end
    end
  end

  def extract_search_data(env)
    # Try to get data from cache first
    cache_key = "env_data:#{env}"
    cached_data = @cache_manager.get(cache_key)
    
    if cached_data
      puts "Cache hit for environment: #{env}" if @options[:debug]
      return cached_data
    end

    puts "Cache miss for environment: #{env}" if @options[:debug]
    
    # Fetch fresh data
    yaml_data = Lotus::Runner.fetch_yaml(env)
    return {} if yaml_data.nil?
    
    search_data = {}
    %w[group configs secrets group_secrets].each do |k|
      search_data[k] = yaml_data[k] if yaml_data.key?(k)
    end
    
    # Cache the data (secrets will be encrypted automatically)
    @cache_manager.set(cache_key, search_data)
    
    search_data
  end

  def perform_search(search_data, env)
    KeySearcher.search(
      search_data,
      @options[:string],
      [],
      [],
      env: env,
      expose: @options[:expose],
      insensitive: @options[:insensitive],
      cache_manager: @cache_manager
    )
  end
end
