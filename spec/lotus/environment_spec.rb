# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Environment do
  # Reset singleton state before each test
  before do
    Lall::CacheManager.reset!
  end

  after do
    Lall::CacheManager.reset!
  end
  describe '#initialize' do
    it 'stores the name and optional parameters' do
      env = Lotus::Environment.new('prod-s5', space: 'custom-space', region: 'use1', application: 'test-app')
      expect(env.name).to eq('prod-s5')
      expect(env.space).to eq('custom-space')
      expect(env.region).to eq('use1')
      expect(env.application).to eq('test-app')
    end

    it 'works with just a name parameter' do
      env = Lotus::Environment.new('staging')
      expect(env.name).to eq('staging')
      expect(env.application).to eq('greenhouse') # default
    end

    it 'accepts a parent parameter' do
      parent = double('EntitySet')
      env = Lotus::Environment.new('prod', parent: parent)
      expect(env.name).to eq('prod')
      expect(env.entity_set).to eq(parent)
    end

    it 'initializes data as nil' do
      env = Lotus::Environment.new('prod')
      expect(env.data).to be_nil
    end
  end

  describe '#space' do
    context 'when space is explicitly provided' do
      it 'returns the provided space' do
        env = Lotus::Environment.new('prod-s5', space: 'custom-space')
        expect(env.space).to eq('custom-space')
      end
    end

    context 'when space is not provided' do
      it 'returns "prod" for prod environments' do
        env = Lotus::Environment.new('prod')
        expect(env.space).to eq('prod')
      end

      it 'returns "prod" for staging environments' do
        env = Lotus::Environment.new('staging')
        expect(env.space).to eq('prod')
      end

      it 'returns "dev" for other environments' do
        env = Lotus::Environment.new('development')
        expect(env.space).to eq('dev')
      end
    end
  end

  describe '#region' do
    context 'when region is explicitly provided' do
      it 'returns the provided region' do
        env = Lotus::Environment.new('prod-s5', region: 'custom-region')
        expect(env.region).to eq('custom-region')
      end
    end

    context 'when region is not provided' do
      it 'returns "use1" for s1-s99 environments' do
        env = Lotus::Environment.new('prod-s5')
        expect(env.region).to eq('use1')
      end

      it 'returns "use1" for environments without numbers' do
        env = Lotus::Environment.new('prod')
        expect(env.region).to eq('use1')
      end

      it 'returns "euc1" for s101-s199 environments' do
        env = Lotus::Environment.new('prod-s150')
        expect(env.region).to eq('euc1')
      end

      it 'returns "apse2" for s201-s299 environments' do
        env = Lotus::Environment.new('prod-s250')
        expect(env.region).to eq('apse2')
      end

      it 'returns nil for numbers outside defined ranges' do
        env = Lotus::Environment.new('prod-s300')
        expect(env.region).to be_nil
      end
    end
  end

  describe '#application' do
    context 'when application is explicitly provided' do
      it 'returns the provided application' do
        env = Lotus::Environment.new('prod', application: 'custom-app')
        expect(env.application).to eq('custom-app')
      end
    end

    context 'when application is not provided' do
      it 'returns "greenhouse" as default' do
        env = Lotus::Environment.new('prod')
        expect(env.application).to eq('greenhouse')
      end
    end
  end

  describe '#data' do
    it 'is initially nil since no data loading method exists yet' do
      env = Lotus::Environment.new('prod')
      expect(env.data).to be_nil
    end
  end

  # Note: The following methods (group_name, configs, secret_keys, group_secret_keys) 
  # currently expect @data to be populated, but there's no mechanism to populate it
  # in the current implementation. These would need data loading functionality.
  describe 'data-dependent methods' do
    describe '#group_name' do
      it 'raises NoMethodError when @data is nil' do
        env = Lotus::Environment.new('prod')
        expect { env.group_name }.to raise_error(NoMethodError, /requires data to be loaded first/)
      end

      it 'returns group name when data is loaded' do
        env = Lotus::Environment.new('prod')
        env.instance_variable_set(:@data, { 'group' => 'test-group' })
        expect(env.group_name).to eq('test-group')
      end
    end

    describe '#group' do
      it 'returns nil when no group is loaded' do
        env = Lotus::Environment.new('prod')
        expect(env.group).to be_nil
      end

      it 'returns group instance when loaded' do
        env = Lotus::Environment.new('prod')
        group = Lotus::Group.new({})
        env.instance_variable_set(:@group, group)
        expect(env.group).to eq(group)
      end
    end

    describe '#configs' do
      it 'will fail when @data is nil (current implementation issue)' do
        env = Lotus::Environment.new('prod')
        expect { env.configs }.to raise_error(NoMethodError)
      end
    end

    describe '#secret_keys' do
      it 'will fail when @data is nil (current implementation issue)' do
        env = Lotus::Environment.new('prod')
        expect { env.secret_keys }.to raise_error(NoMethodError)
      end
    end

    describe '#group_secret_keys' do
      it 'will fail when @data is nil (current implementation issue)' do
        env = Lotus::Environment.new('prod')
        expect { env.group_secret_keys }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#fetch' do
    let(:env) { Lotus::Environment.new('prod') }
    
    let(:sample_env_data) do
      {
        'configs' => { 'api_url' => 'https://api.prod.com' },
        'secrets' => { 'keys' => ['api_key', 'db_password'] },
        'group' => 'prod-group'
      }
    end

    it 'delegates to Lotus::Runner.fetch' do
      expect(Lotus::Runner).to receive(:fetch).with(env).and_return(sample_env_data)
      
      result = env.fetch
      expect(result).to eq(sample_env_data)
    end

    it 'returns cached data if already loaded' do
      env.instance_variable_set(:@data, sample_env_data)
      
      expect(Lotus::Runner).not_to receive(:fetch)
      result = env.fetch
      
      expect(result).to eq(sample_env_data)
    end
  end

  describe '#lotus_cmd' do
    it 'constructs correct lotus command' do
      env = Lotus::Environment.new('prod-s5')
      expected_cmd = 'lotus view -s prod -r use1 -e prod-s5 -a greenhouse -G'
      expect(env.lotus_cmd).to eq(expected_cmd)
    end

    it 'handles environment without region' do
      env = Lotus::Environment.new('development')
      expected_cmd = 'lotus view -s dev -r use1 -e development -a greenhouse -G'
      expect(env.lotus_cmd).to eq(expected_cmd)
    end
  end

  describe '#lotus_parse' do
    let(:env) { Lotus::Environment.new('prod') }
    let(:raw_data) do
      {
        'configs' => { 'api_url' => 'https://api.prod.com' },
        'secrets' => { 'keys' => ['api_key'] },
        'group' => 'prod-group'
      }
    end

    it 'returns the raw data as-is' do
      result = env.lotus_parse(raw_data)
      expect(result).to eq(raw_data)
    end
  end

  describe '#fetch_secrets' do
    let(:env) { Lotus::Environment.new('prod') }
    
    before do
      # Set up environment with sample data including secret keys
      env.instance_variable_set(:@data, {
        'secrets' => { 'keys' => ['DB_PASSWORD', 'API_KEY', 'SOLR_URL', 'REDIS_PASSWORD'] },
        'group_secrets' => { 'keys' => ['SHARED_SECRET', 'SOLR_HOST'] },
        'group' => 'prod-group'
      })
    end

    it 'raises error when data is not loaded' do
      empty_env = Lotus::Environment.new('test')
      expect { empty_env.fetch_secrets('*') }.to raise_error(NoMethodError, /requires data to be loaded first/)
    end

    it 'finds and fetches matching environment secrets' do
      # Mock Lotus::Runner.fetch_all
      expect(Lotus::Runner).to receive(:fetch_all) do |secret_entities|
        # Should find both SOLR_URL (environment) and SOLR_HOST (group)
        expect(secret_entities.length).to eq(2)
        names = secret_entities.map(&:name)
        expect(names).to contain_exactly('SOLR_URL', 'SOLR_HOST')
        secret_entities
      end

      secrets = env.fetch_secrets('*SOLR*')
      
      expect(secrets.length).to eq(2)
      expect(secrets.all? { |s| s.is_a?(Lotus::Secret) }).to be true
      expect(env.secrets).to eq(secrets)
    end

    it 'finds secrets with environment-only pattern' do
      # Mock Lotus::Runner.fetch_all
      expect(Lotus::Runner).to receive(:fetch_all) do |secret_entities|
        expect(secret_entities.length).to eq(1)
        expect(secret_entities.first.name).to eq('API_KEY')
        secret_entities
      end

      secrets = env.fetch_secrets('API_*')
      
      expect(secrets.length).to eq(1)
      expect(secrets.first.name).to eq('API_KEY')
    end

    it 'finds secrets with group-only pattern' do
      # Mock Lotus::Runner.fetch_all
      expect(Lotus::Runner).to receive(:fetch_all) do |secret_entities|
        expect(secret_entities.length).to eq(1)
        expect(secret_entities.first.name).to eq('SHARED_SECRET')
        secret_entities
      end

      secrets = env.fetch_secrets('SHARED_*')
      
      expect(secrets.length).to eq(1)
      expect(secrets.first.name).to eq('SHARED_SECRET')
    end

    it 'finds secrets from both environment and group sources' do
      # Mock Lotus::Runner.fetch_all
      expect(Lotus::Runner).to receive(:fetch_all) do |secret_entities|
        expect(secret_entities.length).to eq(2)
        names = secret_entities.map(&:name)
        expect(names).to contain_exactly('SOLR_URL', 'SOLR_HOST')
        secret_entities
      end

      secrets = env.fetch_secrets('*SOLR*')
      expect(secrets.length).to eq(2)
    end

    it 'returns empty array when no secrets match pattern' do
      secrets = env.fetch_secrets('*NONEXISTENT*')
      expect(secrets).to eq([])
      expect(env.secrets).to eq([])
    end

    it 'supports different glob patterns' do
      # Test *_PASSWORD pattern
      expect(Lotus::Runner).to receive(:fetch_all) do |secret_entities|
        names = secret_entities.map(&:name)
        expect(names).to contain_exactly('DB_PASSWORD', 'REDIS_PASSWORD')
        secret_entities
      end

      secrets = env.fetch_secrets('*_PASSWORD')
      expect(secrets.length).to eq(2)
    end

    it 'is case insensitive' do
      expect(Lotus::Runner).to receive(:fetch_all) do |secret_entities|
        # Should find both SOLR_URL and SOLR_HOST (case insensitive)
        expect(secret_entities.length).to eq(2)
        names = secret_entities.map(&:name)
        expect(names).to contain_exactly('SOLR_URL', 'SOLR_HOST')
        secret_entities
      end

      secrets = env.fetch_secrets('*solr*')
      expect(secrets.length).to eq(2)
    end
  end
end
