# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LallCLI do
  let(:settings_path) { '/Users/eric.griffith/dev/lall/test/fixtures/test_settings.yml' }
  
  before do
    # Stub the settings constant to use test fixtures
    stub_const('SETTINGS_PATH', settings_path)
    stub_const('SETTINGS', YAML.load_file(settings_path))
    stub_const('ENV_GROUPS', YAML.load_file(settings_path)['groups'])
  end

  describe '#initialize' do
    context 'with valid arguments' do
      it 'parses string and environment options' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'prod,staging'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:string]).to eq('api_token')
        expect(options[:env]).to eq('prod,staging')
      end

      it 'parses string and group options' do
        cli = LallCLI.new(['-s', 'secret_*', '-g', 'test'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:string]).to eq('secret_*')
        expect(options[:group]).to eq('test')
      end

      it 'parses boolean flags' do
        cli = LallCLI.new(['-s', 'token', '-e', 'prod', '-p', '-i', '-v', '-x', '-d'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:path_also]).to be true
        expect(options[:insensitive]).to be true
        expect(options[:pivot]).to be true
        expect(options[:expose]).to be true
        expect(options[:debug]).to be true
      end

      it 'parses truncate option with value' do
        cli = LallCLI.new(['-s', 'token', '-e', 'prod', '-t50'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:truncate]).to eq(50)
      end

      it 'parses truncate option without value (uses default)' do
        cli = LallCLI.new(['-s', 'token', '-e', 'prod', '-t'])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:truncate]).to eq(40)
      end
    end

    context 'with long-form options' do
      it 'parses long-form options' do
        cli = LallCLI.new([
          '--string=api_token',
          '--env=prod,staging',
          '--path',
          '--insensitive',
          '--pivot',
          '--truncate=60',
          '--expose',
          '--debug'
        ])
        options = cli.instance_variable_get(:@options)
        
        expect(options[:string]).to eq('api_token')
        expect(options[:env]).to eq('prod,staging')
        expect(options[:path_also]).to be true
        expect(options[:insensitive]).to be true
        expect(options[:pivot]).to be true
        expect(options[:truncate]).to eq(60)
        expect(options[:expose]).to be true
        expect(options[:debug]).to be true
      end
    end
  end

  describe '#run' do
    context 'with invalid arguments' do
      it 'exits with error when string is missing' do
        cli = LallCLI.new(['-e', 'prod'])
        
        expect { cli.run }.to output(/Usage:/).to_stdout.and raise_error(SystemExit)
      end

      it 'exits with error when both env and group are missing' do
        cli = LallCLI.new(['-s', 'token'])
        
        expect { cli.run }.to output(/Usage:/).to_stdout.and raise_error(SystemExit)
      end

      it 'exits with error when both env and group are provided' do
        cli = LallCLI.new(['-s', 'token', '-e', 'prod', '-g', 'test'])
        
        expect { cli.run }.to output(/mutually exclusive/).to_stdout.and raise_error(SystemExit)
      end

      it 'exits with error for unknown group' do
        cli = LallCLI.new(['-s', 'token', '-g', 'unknown_group'])
        
        expect { cli.run }.to output(/Unknown group:/).to_stdout.and raise_error(SystemExit)
      end
    end

    context 'with valid arguments' do
      before do
        # Mock the external lotus command calls
        allow(Lotus::Runner).to receive(:ping).and_return(true)
        allow(Lotus::Runner).to receive(:fetch_yaml).and_return({
          'group' => 'test-group',
          'configs' => { 'api_token' => 'test_token_123' },
          'secrets' => { 'keys' => ['secret_key'] }
        })
        allow(KeySearcher).to receive(:search).and_return([
          { path: 'configs.api_token', key: 'api_token', value: 'test_token_123' }
        ])
      end

      it 'processes environment list from -e option' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'prod,staging'])
        
        expect(Lotus::Runner).to receive(:fetch_yaml).with('prod')
        expect(Lotus::Runner).to receive(:fetch_yaml).with('staging')
        expect { cli.run }.to output(/api_token/).to_stdout
      end

      it 'processes environment list from -g option' do
        cli = LallCLI.new(['-s', 'api_token', '-g', 'test'])
        
        expect(Lotus::Runner).to receive(:fetch_yaml).with('test-env1')
        expect(Lotus::Runner).to receive(:fetch_yaml).with('test-env2')
        expect { cli.run }.to output(/api_token/).to_stdout
      end

      it 'pings unique s_args before fetching' do
        allow(Lotus::Runner).to receive(:get_lotus_args).and_return(['prod', nil])
        cli = LallCLI.new(['-s', 'token', '-e', 'prod,prod-s2'])
        
        expect(Lotus::Runner).to receive(:ping).with('prod').once
        expect { cli.run }.to output.to_stdout
      end

      it 'handles no results found' do
        allow(KeySearcher).to receive(:search).and_return([])
        cli = LallCLI.new(['-s', 'nonexistent', '-e', 'prod'])
        
        expect { cli.run }.to output(/No keys found/).to_stdout
      end
    end

    context 'with different output formats' do
      let(:env_results) do
        {
          'env1' => [{ path: 'configs.api_token', key: 'api_token', value: 'token1' }],
          'env2' => [{ path: 'configs.api_token', key: 'api_token', value: 'token2' }]
        }
      end

      before do
        allow(Lotus::Runner).to receive(:ping).and_return(true)
        allow(Lotus::Runner).to receive(:fetch_yaml).and_return({ 'configs' => {} })
        cli_instance = double('cli')
        allow(cli_instance).to receive(:fetch_env_results).and_return(env_results)
      end

      it 'calls pivot table format when -v is specified' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'env1,env2', '-v'])
        allow(cli).to receive(:fetch_env_results).and_return(env_results)
        
        formatter = double('formatter')
        expect(TableFormatter).to receive(:new).and_return(formatter)
        expect(formatter).to receive(:print_table)
        
        cli.run
      end

      it 'calls path table format when -p is specified' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'env1,env2', '-p'])
        allow(cli).to receive(:fetch_env_results).and_return(env_results)
        
        formatter = double('formatter')
        expect(TableFormatter).to receive(:new).and_return(formatter)
        expect(formatter).to receive(:print_path_table)
        
        cli.run
      end

      it 'calls key table format by default' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'env1,env2'])
        allow(cli).to receive(:fetch_env_results).and_return(env_results)
        
        formatter = double('formatter')
        expect(TableFormatter).to receive(:new).and_return(formatter)
        expect(formatter).to receive(:print_key_table)
        
        cli.run
      end
    end
  end

  describe '#fetch_env_results' do
    let(:cli) { LallCLI.new(['-s', 'token', '-e', 'env1']) }
    let(:yaml_data) { { 'configs' => { 'api_token' => 'test123' } } }

    before do
      allow(Lotus::Runner).to receive(:fetch_yaml).and_return(yaml_data)
      allow(KeySearcher).to receive(:search).and_return([
        { path: 'configs.api_token', key: 'api_token', value: 'test123' }
      ])
    end

    it 'fetches results for all environments in parallel' do
      envs = ['env1', 'env2']
      
      expect(Lotus::Runner).to receive(:fetch_yaml).with('env1')
      expect(Lotus::Runner).to receive(:fetch_yaml).with('env2')
      
      results = cli.send(:fetch_env_results, envs)
      expect(results.keys).to contain_exactly('env1', 'env2')
    end

    it 'extracts relevant data sections for searching' do
      envs = ['env1']
      expected_search_data = {
        'configs' => { 'api_token' => 'test123' }
      }
      
      expect(KeySearcher).to receive(:search).with(
        expected_search_data,
        anything,
        anything,
        anything,
        anything,
        hash_including(env: 'env1')
      )
      
      cli.send(:fetch_env_results, envs)
    end

    it 'passes correct options to KeySearcher' do
      cli = LallCLI.new(['-s', 'token', '-e', 'env1', '-i', '-x', '-d'])
      
      expect(KeySearcher).to receive(:search).with(
        anything,
        'token',
        [],
        [],
        true, # insensitive
        hash_including(env: 'env1', expose: true, debug: true)
      )
      
      cli.send(:fetch_env_results, ['env1'])
    end
  end
end
