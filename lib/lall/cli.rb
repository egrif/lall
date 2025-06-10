# lib/lall/cli.rb
require 'optparse'
require 'yaml'
require_relative 'lotus_runner'
require_relative 'key_searcher'
require_relative 'table_formatter'

SETTINGS_PATH = File.expand_path('../../../config/settings.yml', __FILE__)
SETTINGS = YAML.load_file(SETTINGS_PATH)
ENV_GROUPS = SETTINGS['groups']

class LallCLI
  def initialize(argv)
    @options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: ruby lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [-p] [-i] [-v]"
      opts.on('-sSTRING', '--string=STRING', 'String to search for in YAML keys (required)') { |v| @options[:string] = v }
      opts.on('-eENV', '--env=ENV', 'Comma-separated environment(s) to search, e.g., prod,stage (mutually exclusive with -g)') { |v| @options[:env] = v }
      opts.on('-gGROUP', '--group=GROUP', 'Group name to use a related list of environments (mutually exclusive with -e)') { |v| @options[:group] = v }
      opts.on('-p', '--path', 'Include the path column in the output table (optional)') { @options[:path_also] = true }
      opts.on('-i', '--insensitive', 'Case-insensitive key search (optional)') { @options[:insensitive] = true }
      opts.on('-v', '--pivot', 'Pivot the table so environments are rows and keys/paths are columns (optional)') { @options[:pivot] = true }
      opts.on('-t[LEN]', '--truncate[=LEN]', Integer, 'Truncate output values longer than LEN (default 40) with ellipsis in the middle') do |v|
        @options[:truncate] = v.nil? ? 40 : v
      end
      opts.on('-x', '--expose', 'Expose secrets (show actual secret values for secrets/group_secrets keys)') { @options[:expose] = true }
    end.parse!(argv)
  end

  def run
    if @options[:string].nil? || (@options[:env].nil? && @options[:group].nil?) || (@options[:env] && @options[:group])
      puts "Usage: ruby lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [-p]"
      puts "  -e and -g are mutually exclusive and one is required."
      exit 1
    end
    envs = if @options[:group]
      ENV_GROUPS[@options[:group]] || (puts("Unknown group: \\#{@options[:group]}"); exit 1)
    else
      @options[:env].split(',').map(&:strip)
    end
    # Ping each unique -s value before fetching results
    s_args = envs.map { |env| LotusRunner.get_lotus_args(env).first }.uniq
    s_args.each { |s_arg| LotusRunner.ping(s_arg) }
    env_results = fetch_env_results(envs)
    all_keys = env_results.values.flatten.map { |r| r[:key] }.uniq
    all_paths = env_results.values.flatten.map { |r| r[:path] }.uniq
    if all_keys.empty?
      puts "No keys found containing '#{@options[:string]}'."
      return
    end
    if @options[:pivot]
      columns = all_keys
      columns = all_paths.product(all_keys).map { |p, k| { path: p, key: k } } if @options[:path_also]
      TableFormatter.new(columns, envs, env_results, @options).print_table
    elsif @options[:path_also]
      TableFormatter.new([], envs, env_results, @options).print_path_table(all_paths, all_keys, envs, env_results)
    else
      TableFormatter.new([], envs, env_results, @options).print_key_table(all_keys, envs, env_results)
    end
  end

  def fetch_env_results(envs)
    env_results = {}
    mutex = Mutex.new
    threads = []
    envs.each do |env|
      threads << Thread.new do
        yaml_data = LotusRunner.fetch_yaml(env)
        result = KeySearcher.search(
          yaml_data,
          @options[:string],
          [],
          [],
          @options[:insensitive],
          env: env,
          expose: @options[:expose]
        )
        mutex.synchronize { env_results[env] = result }
      end
    end
    threads.each(&:join)
    env_results
  end
end
