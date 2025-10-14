# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lall::SettingsManager do
  # Reset singleton state before each test
  before do
    described_class.reset!
  end

  after do
    described_class.reset!
  end

  describe '.instance' do
    it 'returns singleton instance' do
      manager1 = described_class.instance({ truncate: 50 })
      manager2 = described_class.instance
      
      expect(manager1).to be(manager2)
    end

    it 'creates new instance when options provided to existing instance' do
      manager1 = described_class.instance
      manager2 = described_class.instance({ truncate: 50 })
      
      expect(manager1).not_to be(manager2)
      expect(manager2.instance_variable_get(:@cli_options)).to eq({ truncate: 50 })
    end

    it 'returns empty instance when no options provided to empty singleton' do
      manager = described_class.instance
      expect(manager.instance_variable_get(:@cli_options)).to eq({})
    end
  end

  describe '.reset!' do
    it 'clears singleton instance' do
      manager1 = described_class.instance({ expose: true })
      described_class.reset!
      manager2 = described_class.instance
      
      expect(manager1).not_to be(manager2)
    end
  end

  describe '#get' do
    context 'with CLI options taking priority' do
      let(:cli_options) { { cache_ttl: 7200, debug: true } }
      let(:manager) { described_class.new(cli_options) }

      before do
        ENV['LALL_CACHE_TTL'] = '1800'
        ENV['LALL_DEBUG'] = 'false'
      end

      after do
        ENV.delete('LALL_CACHE_TTL')
        ENV.delete('LALL_DEBUG')
      end

      it 'returns CLI values with highest priority over environment variables' do
        expect(manager.get('cache.ttl')).to eq(7200)
        expect(manager.get('debug')).to be true
      end
    end

    context 'with environment variables' do
      let(:manager) { described_class.new({}) }

      before do
        ENV['LALL_CACHE_TTL'] = '1800'
        ENV['LALL_DEBUG'] = 'true'
        ENV['LALL_CACHE_ENABLED'] = 'false'
      end

      after do
        %w[LALL_CACHE_TTL LALL_DEBUG LALL_CACHE_ENABLED].each { |var| ENV.delete(var) }
      end

      it 'uses environment variables when CLI options not provided' do
        expect(manager.get('cache.ttl')).to eq(1800)
        expect(manager.get('debug')).to be true
        expect(manager.get('cache.enabled')).to be false
      end
    end

    context 'with default values' do
      let(:manager) { described_class.new({}) }

      it 'returns default values when setting not found anywhere' do
        expect(manager.get('cache.ttl', 3600)).to eq(3600)
        expect(manager.get('debug', false)).to be false
        expect(manager.get('nonexistent', 'default')).to eq('default')
      end
    end
  end

  describe '#cache_settings' do
    let(:cli_options) { { cache_ttl: 1200, cache_dir: '/custom/cache' } }
    let(:manager) { described_class.new(cli_options) }

    before do
      ENV['LALL_CACHE_ENABLED'] = 'false'
    end

    after do
      ENV.delete('LALL_CACHE_ENABLED')
    end

    it 'returns resolved cache settings hash' do
      settings = manager.cache_settings
      
      expect(settings[:ttl]).to eq(1200)
      expect(settings[:directory]).to end_with('/custom/cache')
      expect(settings[:enabled]).to be false
      expect(settings[:secret_key_file]).to end_with('/.lall/secret.key')
      expect(settings[:redis_url]).to be_nil
    end
  end

  describe '#cli_settings' do
    # Stub user settings path to avoid using actual user settings file
    before do
      stub_const('Lall::SettingsManager::USER_SETTINGS_PATH', '/nonexistent/path/settings.yml')
    end
    
    let(:cli_options) { { debug: true, truncate: 100 } }
    let(:manager) { described_class.new(cli_options) }

    it 'returns resolved CLI settings hash' do
      settings = manager.cli_settings
      
      expect(settings[:debug]).to be true
      expect(settings[:truncate]).to eq(100)  # CLI option should override default
      expect(settings[:expose]).to be false
      expect(settings[:insensitive]).to be false
      expect(settings[:path_also]).to be false
      expect(settings[:pivot]).to be false
    end

    context 'when no truncate CLI option is provided' do
      let(:cli_options) { { debug: true } }
      let(:manager) { described_class.new(cli_options) }

      it 'uses the settings default for truncate' do
        settings = manager.cli_settings
        
        expect(settings[:truncate]).to eq(0)  # Should use settings default
        expect(settings[:debug]).to be true
      end
    end
  end

  describe 'boolean parsing' do
    let(:manager) { described_class.new({}) }

    after do
      ENV.delete('LALL_DEBUG')
    end

    it 'correctly parses boolean environment variables' do
      ENV['LALL_DEBUG'] = 'true'
      expect(manager.get('debug')).to be true

      ENV['LALL_DEBUG'] = 'false'
      expect(manager.get('debug')).to be false

      ENV['LALL_DEBUG'] = '1'
      expect(manager.get('debug')).to be true

      ENV['LALL_DEBUG'] = '0' 
      expect(manager.get('debug')).to be false
    end
  end

  describe 'integration with gem settings' do
    let(:manager) { described_class.new({}) }

    it 'can access groups from gem settings' do
      groups = manager.groups
      expect(groups).to be_a(Hash)
      # The groups should come from config/settings.yml
      expect(groups.keys).to include('staging', 'prod-us', 'prod-all')
    end
  end

  describe '#ensure_user_settings_exist' do
    let(:manager) { described_class.new({}) }
    let(:test_settings_path) { '/tmp/test_lall_settings.yml' }

    before do
      # Stub the USER_SETTINGS_PATH constant
      stub_const('Lall::SettingsManager::USER_SETTINGS_PATH', test_settings_path)
      # Ensure the test file doesn't exist
      FileUtils.rm_f(test_settings_path)
    end

    after do
      # Clean up
      FileUtils.rm_f(test_settings_path)
      FileUtils.rm_rf(File.dirname(test_settings_path)) if File.dirname(test_settings_path) != '/tmp'
    end

    it 'creates a well-formatted settings file with comments' do
      manager.ensure_user_settings_exist
      
      expect(File.exist?(test_settings_path)).to be true
      content = File.read(test_settings_path)
      
      # Check that it contains comments
      expect(content).to include('# Lall Personal Settings')
      expect(content).to include('# Cache TTL in seconds')
      
      # Check that it contains expected sections
      expect(content).to include('cache:')
      expect(content).to include('output:')
      
      # Check that it's valid YAML
      parsed = YAML.load_file(test_settings_path)
      expect(parsed).to be_a(Hash)
      expect(parsed['cache']).to be_a(Hash)
      expect(parsed['output']).to be_a(Hash)
    end

    it 'does not overwrite existing settings file' do
      # Create an existing file
      File.write(test_settings_path, "existing: content\n")
      
      manager.ensure_user_settings_exist
      
      # Should not have changed
      content = File.read(test_settings_path)
      expect(content).to eq("existing: content\n")
    end
  end
end
