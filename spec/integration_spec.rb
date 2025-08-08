# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require_relative '../lib/lall/cli'

RSpec.describe 'Integration Tests', :integration do
  let(:lall_command) { File.expand_path('../bin/lall', __dir__) }

  # Helper method to capture stdout for in-process CLI testing
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

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
    let(:mock_env1_data) do
      {
        'group' => 'test-group',
        'configs' => {
          'database_url' => 'postgres://localhost:5432/test1',
          'api_token' => 'token_123',
          'timeout' => 30
        },
        'secrets' => {
          'keys' => ['secret_key', 'api_secret']
        }
      }
    end

    let(:mock_env2_data) do
      {
        'group' => 'test-group',
        'configs' => {
          'database_url' => 'postgres://localhost:5432/test2',
          'api_token' => 'token_456',
          'timeout' => 45
        },
        'secrets' => {
          'keys' => ['secret_key', 'different_secret']
        }
      }
    end

    before do
      # Mock Lotus::Runner.fetch_yaml to return our test data
      allow(Lotus::Runner).to receive(:fetch_yaml) do |entity|
        case entity.name
        when 'test-env1'
          mock_env1_data
        when 'test-env2'
          mock_env2_data
        else
          nil
        end
      end
      
      # Mock ping to always succeed
      allow(Lotus::Runner).to receive(:ping).and_return(true)
    end

    it 'performs end-to-end search with table output' do
      # Test CLI directly in-process instead of spawning separate process
      cli = nil
      output = capture_stdout do
        begin
          cli = LallCLI.new(['-s', 'api_token', '-e', 'test-env1,test-env2', '--no-cache'])
          cli.run
        rescue SystemExit => e
          # Capture exit but continue test
          @exit_code = e.status
        end
      end

      expect(@exit_code).to be_nil  # Should not exit
      expect(output).to include('api_token')
      expect(output).to include('test-env1')
      expect(output).to include('test-env2')
      expect(output).to include('token_123')
      expect(output).to include('token_456')
    end

    it 'handles wildcard searches' do
      stdout = capture_stdout do
        begin
          cli = LallCLI.new(['-s', '*_token', '-e', 'test-env1', '--no-cache'])
          cli.run
        rescue SystemExit => e
          @exit_code = e.status
        end
      end

      expect(@exit_code).to be_nil
      expect(stdout).to include('api_token')
    end

    # Note: Secret exposure testing would require mocking Lotus::Secret entities
    # This is a more complex test case that can be implemented separately
    xit 'exposes secrets when -x flag is used' do
      # This test would require mocking Lotus::Secret entities and their data
      # For now, focusing on basic config value retrieval
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
