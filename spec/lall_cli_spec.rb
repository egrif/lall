# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LallCLI do
  before do
    # Stub the settings constant to use test fixtures
    settings_path = File.join(__dir__, '..', 'test', 'fixtures', 'test_settings.yml')
    stub_const('SETTINGS_PATH', settings_path)
    stub_const('SETTINGS', YAML.load_file(settings_path))
    stub_const('ENV_GROUPS', YAML.load_file(settings_path)['groups'])

    # Mock all Lotus::Runner methods to prevent real lotus calls
    allow(Lotus::Runner).to receive(:fetch_yaml).and_return({
      'configs' => { 'test_key' => 'test_value' },
      'secrets' => { 'keys' => ['secret_key'] },
      'group' => 'test-group'
    })
    allow(Lotus::Runner).to receive(:fetch_yaml).and_return({
      'configs' => { 'group_key' => 'group_value' },
      'secrets' => { 'keys' => ['group_secret'] }
    })
    allow(Lotus::Runner).to receive(:ping).and_return(true)
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

      it 'parses truncate option with value' do
        cli = LallCLI.new(['-s', 'token', '-e', 'prod', '-t', '50'])
        options = cli.instance_variable_get(:@options)

        expect(options[:truncate]).to eq(50)
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

    context 'with list groups functionality' do
      it 'prints available groups when -g list is used' do
        cli = LallCLI.new(['-g', 'list'])

        expected_output = <<~OUTPUT
          Available groups:
            staging: staging, staging-s2, staging-s3
            prod-us: prod, prod-s2, prod-s3, prod-s4, prod-s5, prod-s6, prod-s7, prod-s8, prod-s9
            prod-all: prod, prod-s2, prod-s3, prod-s4, prod-s5, prod-s6, prod-s7, prod-s8, prod-s9, prod-s201, prod-s101
        OUTPUT

        expect { cli.run }.to output(expected_output).to_stdout
      end

      it 'does not require string option when using -g list' do
        cli = LallCLI.new(['-g', 'list'])

        expect { cli.run }.not_to raise_error
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
        # Note: KeySearcher has been eliminated - CLI now uses entity-based search
      end

      it 'processes environment list from -e option' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'prod,staging', '--no-cache'])

        # Mock entity-based system
        entity_set = double('entity_set')
        environments = [
          double('prod', name: 'prod', data: { 'configs' => { 'api_token' => 'prod_token' } }, configs: { 'api_token' => 'prod_token' }, secrets: [], group_name: nil),
          double('staging', name: 'staging', data: { 'configs' => { 'api_token' => 'staging_token' } }, configs: { 'api_token' => 'staging_token' }, secrets: [], group_name: nil)
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        
        expect { cli.run }.to output(/api_token/).to_stdout
      end

      it 'processes environment list from -g option' do
        cli = LallCLI.new(['-s', 'api_token', '-g', 'staging', '--no-cache'])

        # Mock entity-based system
        entity_set = double('entity_set')
        environments = [
          double('staging', name: 'staging', data: { 'configs' => { 'api_token' => 'staging_token' } }, configs: { 'api_token' => 'staging_token' }, secrets: [], group_name: nil),
          double('staging-s2', name: 'staging-s2', data: { 'configs' => { 'api_token' => 'staging_s2_token' } }, configs: { 'api_token' => 'staging_s2_token' }, secrets: [], group_name: nil),
          double('staging-s3', name: 'staging-s3', data: { 'configs' => { 'api_token' => 'staging_s3_token' } }, configs: { 'api_token' => 'staging_s3_token' }, secrets: [], group_name: nil)
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        
        expect { cli.run }.to output(/api_token/).to_stdout
      end

      it 'processes environments without pinging in entity-based approach' do
        cli = LallCLI.new(['-s', 'token', '-e', 'prod,prod-s2'])

        # Mock entity-based system
        entity_set = double('entity_set')
        environments = [
          double('prod', name: 'prod', data: { 'configs' => { 'token' => 'prod_token' } }, configs: { 'token' => 'prod_token' }, secrets: [], group_name: nil),
          double('prod-s2', name: 'prod-s2', data: { 'configs' => { 'token' => 'prod_s2_token' } }, configs: { 'token' => 'prod_s2_token' }, secrets: [], group_name: nil)
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        
        expect { cli.run }.to output(/token/).to_stdout
      end

      it 'handles no results found' do
        # Mock entity-based system to return empty results
        cli = LallCLI.new(['-s', 'nonexistent', '-e', 'prod'])
        
        entity_set = double('entity_set')
        environments = [
          double('prod', name: 'prod', data: { 'configs' => {} }, configs: {}, secrets: [], group_name: nil)
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)

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
        # Mock entity-based system
        entity_set = double('entity_set')
        environments = [
          double('env1', name: 'env1', data: { 'configs' => { 'api_token' => 'token1' } }),
          double('env2', name: 'env2', data: { 'configs' => { 'api_token' => 'token2' } })
        ]
        
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        
        cli_instance = double('cli')
        allow(cli_instance).to receive(:create_entity_set).and_return(entity_set)
        allow(cli_instance).to receive(:fetch_results_from_entity_set).and_return(env_results)
      end

      it 'calls pivot table format when -v is specified' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'env1,env2', '-v'])
        
        # Mock the entity-based flow
        entity_set = double('entity_set')
        environments = [
          double('env1', name: 'env1', data: { 'configs' => { 'api_token' => 'token1' } }),
          double('env2', name: 'env2', data: { 'configs' => { 'api_token' => 'token2' } })
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        allow(cli).to receive(:fetch_results_from_entity_set).and_return(env_results)

        formatter = double('formatter')
        expect(TableFormatter).to receive(:new).and_return(formatter)
        expect(formatter).to receive(:print_table)

        cli.run
      end

      it 'calls path table format when -p is specified' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'env1,env2', '-p'])
        
        # Mock the entity-based flow
        entity_set = double('entity_set')
        environments = [
          double('env1', name: 'env1', data: { 'configs' => { 'api_token' => 'token1' } }),
          double('env2', name: 'env2', data: { 'configs' => { 'api_token' => 'token2' } })
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        allow(cli).to receive(:fetch_results_from_entity_set).and_return(env_results)

        formatter = double('formatter')
        expect(TableFormatter).to receive(:new).and_return(formatter)
        expect(formatter).to receive(:print_path_table)

        cli.run
      end

      it 'calls key table format by default' do
        cli = LallCLI.new(['-s', 'api_token', '-e', 'env1,env2'])
        
        # Mock the entity-based flow
        entity_set = double('entity_set')
        environments = [
          double('env1', name: 'env1', data: { 'configs' => { 'api_token' => 'token1' } }),
          double('env2', name: 'env2', data: { 'configs' => { 'api_token' => 'token2' } })
        ]
        
        allow(cli).to receive(:create_entity_set).and_return(entity_set)
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        allow(cli).to receive(:fetch_results_from_entity_set).and_return(env_results)

        formatter = double('formatter')
        expect(TableFormatter).to receive(:new).and_return(formatter)
        expect(formatter).to receive(:print_key_table)

        cli.run
      end
    end
  end

end
