# frozen_string_literal: true

require 'open3'
require 'yaml'

module Lotus
  class Runner
    DEBUG_MODE = ARGV.include?('-d') || ARGV.include?('--debug') || ENV.fetch('DEBUG', nil)

    def self.fetch_yaml(env)
      s_arg, r_arg = get_lotus_args(env)
      lotus_cmd = "lotus view -s \\#{s_arg} -e \\#{env} -a greenhouse"
      lotus_cmd += " -r \\#{r_arg}" if r_arg
      yaml_output = nil
      Open3.popen3(lotus_cmd) do |_stdin, stdout, stderr, wait_thr|
        yaml_output = stdout.read
        unless wait_thr.value.success?
          warn "Failed to run lotus command for env '#{env}': \\#{stderr.read}"
          return nil
        end
      end
      YAML.safe_load(yaml_output)
    end

    def self.fetch_group_yaml(env, group_name)
      s_arg, r_arg = get_lotus_args(env)
      lotus_cmd = "lotus view -s \\#{s_arg}"
      lotus_cmd += " -r \\#{r_arg}" if r_arg
      lotus_cmd += " -a greenhouse -g \\#{group_name}"
      yaml_output = nil
      Open3.popen3(lotus_cmd) do |_stdin, stdout, stderr, wait_thr|
        yaml_output = stdout.read
        unless wait_thr.value.success?
          warn "Failed to run lotus command for group '#{group_name}': \\#{stderr.read}"
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
      if env =~ /s(\d+)$/
        num = ::Regexp.last_match(1).to_i
        if num.between?(1, 99)
          r_arg = 'use1'
        elsif num.between?(101, 199)
          r_arg = 'euc1'
        elsif num.between?(201, 299)
          r_arg = 'apse2'
        end
      end
      [s_arg, r_arg]
    end

    def self.secret_get(env, secret_key, group: nil)
      s_arg, r_arg = get_lotus_args(env)
      lotus_cmd = if group
                    "lotus secret get #{secret_key} -s \\#{s_arg} -g \\#{group} -a greenhouse "
                  else
                    "lotus secret get #{secret_key} -s \\#{s_arg} -e \\#{env} -a greenhouse "
                  end
      lotus_cmd += " -r \\#{r_arg}" if r_arg
      # puts lotus_cmd if DEBUG_MODE
      secret_output = nil
      Open3.popen3(lotus_cmd) do |_stdin, stdout, stderr, wait_thr|
        secret_output = stdout.read
        unless wait_thr.value.success?
          warn "Failed to run lotus secret get for env '#{env}', key '#{secret_key}': \\#{stderr.read}"
          return nil
        end
      end
      # Expect output like KEY=value, return just the value
      if secret_output =~ /^\s*\w+\s*=\s*(.*)$/
        ::Regexp.last_match(1).strip
      else
        secret_output.strip
      end
    end

    def self.secret_get_many(env, secret_keys)
      results = {}
      threads = secret_keys.map do |key|
        Thread.new do
          value = secret_get(env, key)
          results[key] = value
        end
      end
      threads.each(&:join)
      results
    end

    def self.ping(env)
      s_arg, = get_lotus_args(env)
      ping_cmd = "lotus ping -s \\#{s_arg} > /dev/null 2>&1"
      system(ping_cmd)
    end
  end
end
