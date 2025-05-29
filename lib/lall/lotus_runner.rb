# lib/lall/lotus_runner.rb
require 'open3'
require 'yaml'

class LotusRunner
  def self.fetch_yaml(env)
    s_arg, r_arg = get_lotus_args(env)
    lotus_cmd = "lotus view -s \\#{s_arg} -e \\#{env} -a greenhouse -G"
    lotus_cmd += " -r \\#{r_arg}" if r_arg
    yaml_output = nil
    Open3.popen3(lotus_cmd) do |stdin, stdout, stderr, wait_thr|
      yaml_output = stdout.read
      unless wait_thr.value.success?
        warn "Failed to run lotus command for env '#{env}': \\#{stderr.read}"
        return nil
      end
    end
    YAML.safe_load(yaml_output)
  end

  def self.get_lotus_args(env)
    s_arg = if env.start_with?('prod') || env.start_with?('staging')
      'prod'
    else
      env
    end
    r_arg = nil
    if env =~ /s(\\d+)$/
      num = $1.to_i
      if num >= 1 && num <= 99
        r_arg = 'use1'
      elsif num >= 101 && num <= 199
        r_arg = 'euc1'
      elsif num >= 201 && num <= 299
        r_arg = 'apse2'
      end
    end
    [s_arg, r_arg]
  end
end
