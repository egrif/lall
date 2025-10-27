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
      it 'parses match and environment options' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'prod,staging'])
        options = cli.instance_variable_get(:@options)

        expect(options[:match]).to eq('api_token')
        expect(options[:env]).to eq('prod,staging')
      end

      it 'parses match and group options' do
        cli = LallCLI.new(['-m', 'secret_*', '-g', 'test'])
        options = cli.instance_variable_get(:@options)

        expect(options[:match]).to eq('secret_*')
        expect(options[:group]).to eq('test')
      end

      it 'parses comma-separated match patterns' do
        cli = LallCLI.new(['-m', 'DATABASE_*,RAILS_*,API_KEY', '-e', 'prod'])
        options = cli.instance_variable_get(:@options)

        expect(options[:match]).to eq('DATABASE_*,RAILS_*,API_KEY')
        expect(options[:env]).to eq('prod')
      end

      it 'parses boolean flags' do
        cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-p', '-i', '-v', '-x', '-d'])
        options = cli.instance_variable_get(:@options)

        expect(options[:path_also]).to be true
        expect(options[:insensitive]).to be true
        expect(options[:pivot]).to be true
        expect(options[:expose]).to be true
        expect(options[:debug]).to be true
      end

      it 'parses truncate option with value' do
        cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-t50'])
        options = cli.instance_variable_get(:@options)

        expect(options[:truncate]).to eq(50)
      end

      it 'parses truncate option with value' do
        cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-t', '50'])
        options = cli.instance_variable_get(:@options)

        expect(options[:truncate]).to eq(50)
      end

      it 'parses no-truncate option' do
        cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-T'])
        options = cli.instance_variable_get(:@options)

        expect(options[:truncate]).to eq(0)
      end

      context 'with --only option' do
        it 'parses single config type filter' do
          cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-y', 'c'])
          options = cli.instance_variable_get(:@options)

          expect(options[:only][:config_type]).to eq(:config)
          expect(options[:only][:scope_type]).to be_nil
        end

        it 'parses concatenated filters' do
          cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-y', 'ce'])
          options = cli.instance_variable_get(:@options)

          expect(options[:only][:config_type]).to eq(:config)
          expect(options[:only][:scope_type]).to eq(:environment)
        end

        it 'parses comma-separated filters' do
          cli = LallCLI.new(['-m', 'token', '-e', 'prod', '--only=cfg,env'])
          options = cli.instance_variable_get(:@options)

          expect(options[:only][:config_type]).to eq(:config)
          expect(options[:only][:scope_type]).to eq(:environment)
        end

        it 'parses secret and group filters' do
          cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-y', 'sg'])
          options = cli.instance_variable_get(:@options)

          expect(options[:only][:config_type]).to eq(:secret)
          expect(options[:only][:scope_type]).to eq(:group)
        end

        it 'parses long form aliases' do
          cli = LallCLI.new(['-m', 'token', '-e', 'prod', '--only=secret,environment'])
          options = cli.instance_variable_get(:@options)

          expect(options[:only][:config_type]).to eq(:secret)
          expect(options[:only][:scope_type]).to eq(:environment)
        end

        it 'handles invalid filter values' do
          expect {
            LallCLI.new(['-m', 'token', '-e', 'prod', '--only=invalid'])
          }.to raise_error(ArgumentError, /Invalid filter value: 'invalid'/)
        end
      end
    end

    context 'with long-form options' do
      it 'parses long-form options' do
        cli = LallCLI.new([
                            '--match=api_token',
                            '--env=prod,staging',
                            '--path',
                            '--insensitive',
                            '--pivot',
                            '--truncate=60',
                            '--expose',
                            '--debug'
                          ])
        options = cli.instance_variable_get(:@options)

        expect(options[:match]).to eq('api_token')
        expect(options[:env]).to eq('prod,staging')
        expect(options[:path_also]).to be true
        expect(options[:insensitive]).to be true
        expect(options[:pivot]).to be true
        expect(options[:truncate]).to eq(60)
        expect(options[:expose]).to be true
        expect(options[:debug]).to be true
      end

      it 'parses --no-truncate option' do
        cli = LallCLI.new(['-m', 'token', '-e', 'prod', '--no-truncate'])
        options = cli.instance_variable_get(:@options)

        expect(options[:truncate]).to eq(0)
      end
    end
  end

  describe '#run' do
    context 'with export functionality' do
      let(:env_results) do
        {
          'env1' => [{ path: 'configs', key: 'api_token', value: 'token1' }],
          'env2' => [{ path: 'configs', key: 'api_token', value: 'token2' }]
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
        allow_any_instance_of(LallCLI).to receive(:create_entity_set).and_return(entity_set)
        allow_any_instance_of(LallCLI).to receive(:fetch_results_from_entity_set).and_return(env_results)
      end

      it 'exports results as CSV to stdout with --format' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '--format=csv'])
        expect { cli.run }.to output(/Key,env1,env2\napi_token,token1,token2/).to_stdout
      end

      it 'exports results as JSON to stdout with -f' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '-fjson'])
        expect { cli.run }.to output(/"env1":\s*{\s*"api_token":\s*"token1"/).to_stdout
      end

      it 'exports results as YAML to stdout with --format=yaml' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '--format=yaml'])
        expect { cli.run }.to output(/env1:\s*api_token: token1/).to_stdout
      end

      it 'exports results as TXT to stdout with -ftxt' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '-ftxt'])
        expect { cli.run }.to output(/Key\tenv1\tenv2\napi_token\ttoken1\ttoken2/).to_stdout
      end

      it 'displays results in keyvalue format with --format=keyvalue' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '--format=keyvalue'])
        expect { cli.run }.to output(/env1:\s*configs:\s*api_token: 'token1'.*env2:\s*configs:\s*api_token: 'token2'/m).to_stdout
      end

      it 'displays results in keyvalue format with -fkv' do
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '-fkv'])
        expect { cli.run }.to output(/env1:\s*configs:\s*api_token: 'token1'.*env2:\s*configs:\s*api_token: 'token2'/m).to_stdout
      end

      it 'writes exported results to file with --output-file' do
        file = 'tmp/test_export.txt'
        File.delete(file) if File.exist?(file)
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '--format=txt', "--output-file=#{file}"])
        expect { cli.run }.to output(/Exported results to/).to_stdout
        expect(File.read(file)).to include("Key\tenv1\tenv2\napi_token\ttoken1\ttoken2")
        File.delete(file)
      end

      it 'writes exported results to file with -o' do
        file = 'tmp/test_export2.txt'
        File.delete(file) if File.exist?(file)
        cli = LallCLI.new(['-m', 'api_token', '-e', 'env1,env2', '-ftxt', "-o#{file}"])
        expect { cli.run }.to output(/Exported results to/).to_stdout
        expect(File.read(file)).to include("Key\tenv1\tenv2\napi_token\ttoken1\ttoken2")
        File.delete(file)
      end
    end
    context 'with invalid arguments' do
      it 'exits with error when match is missing' do
        cli = LallCLI.new(['-e', 'prod'])

        expect { cli.run }.to output(/Usage:/).to_stdout.and raise_error(SystemExit)
      end

      it 'exits with error when both env and group are missing' do
        cli = LallCLI.new(['-m', 'token'])

        expect { cli.run }.to output(/Usage:/).to_stdout.and raise_error(SystemExit)
      end

      it 'exits with error when both env and group are provided' do
        cli = LallCLI.new(['-m', 'token', '-e', 'prod', '-g', 'test'])

        expect { cli.run }.to output(/mutually exclusive/).to_stdout.and raise_error(SystemExit)
      end

      it 'exits with error for unknown group' do
        cli = LallCLI.new(['-m', 'token', '-g', 'unknown_group'])

        expect { cli.run }.to output(/Unknown group:/).to_stdout.and raise_error(SystemExit)
      end
    end

    context 'with list groups functionality' do
      it 'prints available groups when -g list is used' do
        cli = LallCLI.new(['-g', 'list'])

        expected_output = <<~OUTPUT
          Available groups:
            staging: staging, staging-s2
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

    context 'with comma-separated patterns' do
      let(:env_results) do
        {
          'prod' => [
            { path: 'configs', key: 'DATABASE_URL', value: 'postgres://...', color: :white },
            { path: 'configs', key: 'REDIS_URL', value: 'redis://...', color: :white },
            { path: 'configs', key: 'RAILS_ENV', value: 'production', color: :white },
            { path: 'configs', key: 'API_KEY', value: 'secret123', color: :white }
          ]
        }
      end

      before do
        # Mock entity-based system for comma-separated pattern tests
        entity_set = double('entity_set')
        environments = [
          double('prod', name: 'prod', data: {
            'configs' => {
              'DATABASE_URL' => 'postgres://...',
              'REDIS_URL' => 'redis://...',
              'RAILS_ENV' => 'production',
              'API_KEY' => 'secret123'
            }
          })
        ]
        allow(entity_set).to receive(:fetch_all)
        allow(entity_set).to receive(:environments).and_return(environments)
        allow_any_instance_of(LallCLI).to receive(:create_entity_set).and_return(entity_set)
        allow_any_instance_of(LallCLI).to receive(:fetch_results_from_entity_set).and_return(env_results)
      end

      it 'matches multiple comma-separated patterns' do
        cli = LallCLI.new(['-m', 'DATABASE_URL,RAILS_ENV', '-e', 'prod'])
        
        expect { cli.run }.to output(/DATABASE_URL.*postgres/).to_stdout
        expect { cli.run }.to output(/RAILS_ENV.*production/).to_stdout
      end

      it 'matches comma-separated glob patterns' do
        cli = LallCLI.new(['-m', '*_URL,RAILS_*', '-e', 'prod'])
        
        expect { cli.run }.to output(/DATABASE_URL/).to_stdout
        expect { cli.run }.to output(/REDIS_URL/).to_stdout
        expect { cli.run }.to output(/RAILS_ENV/).to_stdout
      end

      it 'handles whitespace around commas' do
        cli = LallCLI.new(['-m', ' DATABASE_URL , RAILS_ENV ', '-e', 'prod'])
        
        expect { cli.run }.to output(/DATABASE_URL/).to_stdout
        expect { cli.run }.to output(/RAILS_ENV/).to_stdout
      end
    end

    describe 'with settings management' do
      it 'updates user settings when --update-settings is used' do
        cli = LallCLI.new(['--update-settings'])

        expect { cli.run }.to output(/✅ Updated user settings file/).to_stdout.and raise_error(SystemExit)
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

    context 'with version option' do
      it 'displays version and exits' do
        expect do
          LallCLI.new(['--version'])
        end.to output("lall #{Lall::VERSION}\n").to_stdout.and raise_error(SystemExit)
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

  describe 'secret prefix/suffix functionality' do
    let(:cli_with_prefix) { described_class.new(['--match', 'test_*', '--env', 'test-env', '--secret-prefix', 'sec_']) }
    let(:cli_with_suffix) { described_class.new(['--match', 'test_*', '--env', 'test-env', '--secret-postfix', '_secret']) }
    let(:cli_with_both) { described_class.new(['--match', 'test_*', '--env', 'test-env', '--secret-prefix', 'sec_', '--secret-postfix', '_secret']) }

    it 'applies secret prefix to CLI options' do
      expect(cli_with_prefix.instance_variable_get(:@options)[:secret_prefix]).to eq('sec_')
      expect(cli_with_prefix.instance_variable_get(:@options)[:secret_suffix]).to be_nil
    end

    it 'applies secret suffix to CLI options' do
      expect(cli_with_suffix.instance_variable_get(:@options)[:secret_prefix]).to be_nil
      expect(cli_with_suffix.instance_variable_get(:@options)[:secret_suffix]).to eq('_secret')
    end

    it 'applies both prefix and suffix to CLI options' do
      expect(cli_with_both.instance_variable_get(:@options)[:secret_prefix]).to eq('sec_')
      expect(cli_with_both.instance_variable_get(:@options)[:secret_suffix]).to eq('_secret')
    end

    it 'applies secret affixes to secret names' do
      # Test prefix only
      expect(cli_with_prefix.send(:apply_secret_affixes, 'api_key')).to eq('sec_api_key')
      
      # Test suffix only  
      expect(cli_with_suffix.send(:apply_secret_affixes, 'api_key')).to eq('api_key_secret')
      
      # Test both prefix and suffix
      expect(cli_with_both.send(:apply_secret_affixes, 'api_key')).to eq('sec_api_key_secret')
    end

    context 'with --no-secret-prefix and --no-secret-postfix flags' do
      let(:cli_no_prefix) { described_class.new(['--match', 'test_*', '--env', 'test-env', '--no-secret-prefix']) }
      let(:cli_no_suffix) { described_class.new(['--match', 'test_*', '--env', 'test-env', '-P']) }

      it 'disables secret prefix with --no-secret-prefix' do
        expect(cli_no_prefix.instance_variable_get(:@options)[:secret_prefix]).to be_nil
      end

      it 'disables secret suffix with -P/--no-secret-postfix' do
        expect(cli_no_suffix.instance_variable_get(:@options)[:secret_suffix]).to be_nil
      end
    end
  end

end
