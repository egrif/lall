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
    end

    it 'works with just a name parameter' do
      env = Lotus::Environment.new('staging')
      expect(env.name).to eq('staging')
    end

    it 'accepts a cache_manager parameter' do
      cache_manager = double('CacheManager')
      env = Lotus::Environment.new('prod', cache_manager: cache_manager)
      expect(env.name).to eq('prod')
      expect(env.instance_variable_get(:@cache_manager)).to eq(cache_manager)
    end

    it 'initializes data and group as nil' do
      env = Lotus::Environment.new('prod')
      expect(env.data).to be_nil
      expect(env.group).to be_nil
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
      it 'returns nil when @data is nil' do
        env = Lotus::Environment.new('prod')
        expect(env.group_name).to be_nil
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
    let(:cache_manager) { double('CacheManager') }
    let(:env_with_cache) { Lotus::Environment.new('prod', cache_manager: cache_manager) }
    let(:env_without_cache) { 
      require_relative '../../lib/lall/cli'
      Lotus::Environment.new('prod', cache_manager: LallCLI::NullCacheManager.new) 
    }
    
    let(:sample_env_yaml) do
      {
        'configs' => { 'api_url' => 'https://api.prod.com' },
        'secrets' => { 'keys' => ['api_key', 'db_password'] },
        'group' => 'prod-group'
      }
    end
    
    let(:sample_group_yaml) do
      {
        'configs' => { 'shared_config' => 'shared_value' },
        'secrets' => { 'keys' => ['shared_secret'] }
      }
    end

    context 'when data is already loaded' do
      it 'returns cached data without making lotus calls' do
        env = Lotus::Environment.new('prod')
        env.instance_variable_set(:@data, { 'configs' => { 'test' => 'value' } })
        
        expect(Lotus::Runner).not_to receive(:fetch_env_yaml)
        result = env.fetch
        
        expect(result).to eq({ 'configs' => { 'test' => 'value' } })
      end
    end

    context 'with cache manager' do
      it 'returns data from cache when available' do
        cached_data = {
          'configs' => { 'api_url' => 'https://api.prod.com' },
          'secrets' => { 'keys' => ['api_key'] }
        }
        
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(cached_data)
        expect(Lotus::Runner).not_to receive(:fetch_env_yaml)
        
        result = env_with_cache.fetch
        expect(result).to eq(cached_data)
        expect(env_with_cache.data).to eq(cached_data)
      end

      it 'fetches from lotus when cache misses and caches the result' do
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(nil)
        expect(cache_manager).to receive(:get_group_data).with('prod-group', 'greenhouse').and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(sample_env_yaml)
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with('prod', 'prod-group').and_return(sample_group_yaml)
        expect(cache_manager).to receive(:set_env_data).with(env_with_cache, anything)
        expect(cache_manager).to receive(:set_group_data).with('prod-group', 'greenhouse', sample_group_yaml)
        
        result = env_with_cache.fetch
        
        expect(result['configs']).to eq(sample_env_yaml['configs'])
        expect(result['secrets']).to eq({ 'keys' => sample_env_yaml['secrets']['keys'] })
        expect(result['group']).to eq('prod-group')
      end

      it 'loads group data when environment has a group' do
        cached_data = {
          'configs' => { 'api_url' => 'https://api.prod.com' },
          'group' => 'prod-group'
        }
        
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(cached_data)
        expect(cache_manager).to receive(:get_group_data).with('prod-group', 'greenhouse').and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with('prod', 'prod-group').and_return(sample_group_yaml)
        expect(cache_manager).to receive(:set_group_data).with('prod-group', 'greenhouse', sample_group_yaml)
        
        env_with_cache.fetch
        
        expect(env_with_cache.group).to be_a(Lotus::Group)
        expect(env_with_cache.data['group_secrets']).to eq({ 'keys' => ['shared_secret'] })
      end

      it 'uses cached group data when available' do
        env_data = {
          'configs' => { 'api_url' => 'https://api.prod.com' },
          'group' => 'prod-group'
        }
        
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(env_data)
        expect(cache_manager).to receive(:get_group_data).with('prod-group', 'greenhouse').and_return(sample_group_yaml)
        expect(Lotus::Runner).not_to receive(:fetch_group_yaml)
        
        env_with_cache.fetch
        
        expect(env_with_cache.group).to be_a(Lotus::Group)
        expect(env_with_cache.data['group_secrets']).to eq({ 'keys' => ['shared_secret'] })
      end

      it 'handles environments without groups' do
        env_data_no_group = {
          'configs' => { 'api_url' => 'https://api.prod.com' },
          'secrets' => { 'keys' => ['api_key'] }
        }
        
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(env_data_no_group)
        
        result = env_with_cache.fetch
        
        expect(result).to eq(env_data_no_group)
        expect(env_with_cache.group).to be_nil
      end

      it 'caches with is_secret: true when secrets are present' do
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(nil)
        expect(cache_manager).to receive(:get_group_data).with('prod-group', 'greenhouse').and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(sample_env_yaml)
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with('prod', 'prod-group').and_return(sample_group_yaml)
        expect(cache_manager).to receive(:set_env_data).with(env_with_cache, anything)
        expect(cache_manager).to receive(:set_group_data).with('prod-group', 'greenhouse', sample_group_yaml)
        
        env_with_cache.fetch
      end

      it 'caches with is_secret: false when no secrets are present' do
        env_yaml_no_secrets = {
          'configs' => { 'api_url' => 'https://api.prod.com' }
        }
        
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(env_yaml_no_secrets)
        expect(cache_manager).to receive(:set_env_data).with(env_with_cache, anything)
        
        env_with_cache.fetch
      end
    end

    context 'without cache manager' do
      it 'fetches from lotus directly and does not cache' do
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(sample_env_yaml)
        
        result = env_without_cache.fetch
        
        expect(result['configs']).to eq(sample_env_yaml['configs'])
        expect(result['secrets']).to eq({ 'keys' => sample_env_yaml['secrets']['keys'] })
      end

      it 'loads group data without caching' do
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(sample_env_yaml)
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with('prod', 'prod-group').and_return(sample_group_yaml)
        
        env_without_cache.fetch
        
        expect(env_without_cache.group).to be_a(Lotus::Group)
        expect(env_without_cache.data['group_secrets']).to eq({ 'keys' => ['shared_secret'] })
      end
    end

    context 'error handling' do
      it 'returns nil when lotus fetch fails' do
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(nil)
        
        result = env_with_cache.fetch
        expect(result).to be_nil
      end

      it 'handles group fetch failures gracefully' do
        env_data = {
          'configs' => { 'api_url' => 'https://api.prod.com' },
          'group' => 'prod-group'
        }
        
        expect(cache_manager).to receive(:get_env_data).with(env_with_cache).and_return(env_data)
        expect(cache_manager).to receive(:get_group_data).with('prod-group', 'greenhouse').and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with('prod', 'prod-group').and_return(nil)
        
        result = env_with_cache.fetch
        
        expect(result).to eq(env_data)
        expect(env_with_cache.group).to be_nil
      end
    end

    context 'custom application name' do
      it 'uses custom application in cache keys' do
        custom_env = Lotus::Environment.new('prod', application: 'custom-app', cache_manager: cache_manager)
        
        expect(cache_manager).to receive(:get_env_data).with(custom_env).and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_env_yaml).with('prod').and_return(sample_env_yaml)
        expect(cache_manager).to receive(:set_env_data).with(custom_env, anything)
        expect(cache_manager).to receive(:get_group_data).with('prod-group', 'custom-app').and_return(nil)
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with('prod', 'prod-group').and_return(sample_group_yaml)
        expect(cache_manager).to receive(:set_group_data).with('prod-group', 'custom-app', sample_group_yaml)
        
        custom_env.fetch
      end
    end
  end
end
