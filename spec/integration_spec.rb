# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Integration Tests', :integration do
  let(:lall_command) { File.expand_path('../bin/lall', __dir__) }

  describe 'CLI executable' do
    it 'shows usage when no arguments provided' do
      stdout, _, status = Open3.capture3(lall_command)

      expect(status.exitstatus).to eq(1)
      expect(stdout).to include('Usage:')
    end

    it 'shows usage when required arguments are missing' do
      stdout, _, status = Open3.capture3(lall_command, '-s', 'token')

      expect(status.exitstatus).to eq(1)
      expect(stdout).to include('mutually exclusive and one is required')
    end

    it 'shows error for unknown group' do
      stdout, _, status = Open3.capture3(lall_command, '-s', 'token', '-g', 'nonexistent')

      expect(status.exitstatus).to eq(1)
      expect(stdout).to include('Unknown group: nonexistent')
    end
  end

  describe 'Full workflow with mocked lotus commands' do
    let(:mock_lotus_script) do
      <<~SCRIPT
        #!/bin/bash

        if [[ "$1" == "ping" ]]; then
          exit 0
        elif [[ "$1" == "view" ]]; then
          if [[ "$*" == *"-e \\\\test-env1"* ]]; then
            cat << 'EOF'
        group: test-group
        configs:
          database_url: postgres://localhost:5432/test1
          api_token: token_123
          timeout: 30
        secrets:
          keys:
            - secret_key
            - api_secret
        EOF
          elif [[ "$*" == *"-e \\\\test-env2"* ]]; then
            cat << 'EOF'
        group: test-group
        configs:
          database_url: postgres://localhost:5432/test2
          api_token: token_456
          timeout: 45
        secrets:
          keys:
            - secret_key
            - different_secret
        EOF
          fi
        elif [[ "$1" == "secret" ]] && [[ "$2" == "get" ]]; then
          echo "SECRET_KEY=actual_secret_value_$(date +%s)"
        fi
      SCRIPT
    end

    let(:temp_lotus_path) { '/tmp/mock_lotus' }

    before do
      # Create mock lotus command
      File.write(temp_lotus_path, mock_lotus_script)
      File.chmod(0o755, temp_lotus_path)

      # Temporarily modify PATH to use mock lotus
      @original_path = ENV.fetch('PATH', nil)
      ENV['PATH'] = "/tmp:#{ENV.fetch('PATH', nil)}"
    end

    after do
      ENV['PATH'] = @original_path
      File.delete(temp_lotus_path) if File.exist?(temp_lotus_path)
    end

    xit 'performs end-to-end search with table output' do
      # Skip this test in CI or when lotus is not available
      skip 'Requires lotus command' unless system('which lotus > /dev/null 2>&1') || File.exist?(temp_lotus_path)

      stdout, _, status = Open3.capture3(
        lall_command, '-s', 'api_token', '-e', 'test-env1,test-env2'
      )

      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('api_token')
      expect(stdout).to include('test-env1')
      expect(stdout).to include('test-env2')
      expect(stdout).to include('token_123')
      expect(stdout).to include('token_456')
    end

    xit 'handles wildcard searches' do
      skip 'Requires lotus command' unless system('which lotus > /dev/null 2>&1') || File.exist?(temp_lotus_path)

      stdout, _, status = Open3.capture3(
        lall_command, '-s', '*_token', '-e', 'test-env1'
      )

      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('api_token')
    end

    xit 'exposes secrets when -x flag is used' do
      skip 'Requires lotus command' unless system('which lotus > /dev/null 2>&1') || File.exist?(temp_lotus_path)

      stdout, _, status = Open3.capture3(
        lall_command, '-s', 'secret_key', '-e', 'test-env1', '-x'
      )

      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('actual_secret_value')
    end
  end

  describe 'Error handling' do
    it 'handles invalid command line options gracefully' do
      _, _, status = Open3.capture3(lall_command, '--invalid-option')

      expect(status.exitstatus).to eq(1)
    end

    it 'validates mutually exclusive options' do
      stdout, _, status = Open3.capture3(
        lall_command, '-s', 'token', '-e', 'env1', '-g', 'group1'
      )

      expect(status.exitstatus).to eq(1)
      expect(stdout).to include('mutually exclusive')
    end
  end
end
