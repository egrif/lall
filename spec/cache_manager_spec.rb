require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Lall::CacheManager do
  let(:test_cache_dir) { Dir.mktmpdir('lall_cache_test') }
  let(:test_secret_key_file) { File.join(test_cache_dir, 'secret.key') }
  let(:cache_config) do
    {
      enabled: true,
      ttl: 60,
      cache_dir: test_cache_dir,
      secret_key_file: test_secret_key_file,
      redis_url: nil
    }
  end

  # Reset singleton state before each test
  before do
    described_class.reset!
  end

  after do
    described_class.reset!
    FileUtils.rm_rf(test_cache_dir) if Dir.exist?(test_cache_dir)
  end

  describe '.instance' do
    it 'returns singleton instance' do
      manager1 = described_class.instance(cache_config)
      manager2 = described_class.instance
      
      expect(manager1).to be(manager2)
    end

    it 'creates new instance when options provided to existing instance' do
      manager1 = described_class.instance
      manager2 = described_class.instance(cache_config)
      
      expect(manager1).not_to be(manager2)
    end

    it 'returns default instance when no options provided' do
      manager = described_class.instance
      expect(manager).to be_a(described_class)
    end
  end

  describe '.reset!' do
    it 'clears singleton instance' do
      manager1 = described_class.instance(cache_config)
      described_class.reset!
      manager2 = described_class.instance
      
      expect(manager1).not_to be(manager2)
    end
  end

  describe '#initialize' do
    context 'with moneta backend' do
      it 'initializes with moneta backend when redis_url is nil' do
        manager = Lall::CacheManager.new(cache_config)
        expect(manager.stats[:backend]).to eq('moneta')
        expect(manager.enabled?).to be true
      end

      it 'creates cache directory if it does not exist' do
        FileUtils.rm_rf(test_cache_dir)
        expect(Dir.exist?(test_cache_dir)).to be false
        
        Lall::CacheManager.new(cache_config)
        expect(Dir.exist?(test_cache_dir)).to be true
      end

      it 'generates encryption key if it does not exist' do
        expect(File.exist?(test_secret_key_file)).to be false
        
        Lall::CacheManager.new(cache_config)
        expect(File.exist?(test_secret_key_file)).to be true
        expect(File.binread(test_secret_key_file).length).to eq(32) # Should be exactly 32 bytes
      end
    end

    context 'when disabled' do
      it 'initializes as disabled when enabled is false' do
        cache_config[:enabled] = false
        manager = Lall::CacheManager.new(cache_config)
        expect(manager.enabled?).to be false
      end
    end
  end

  describe '#get and #set' do
    let(:manager) { Lall::CacheManager.new(cache_config) }
    let(:test_key) { 'test_environment' }
    let(:test_data) { { 'configs' => { 'api_token' => 'secret123' } } }

    it 'stores and retrieves non-secret data' do
      manager.set(test_key, test_data, is_secret: false)
      result = manager.get(test_key)
      expect(result).to eq(test_data)
    end

    it 'stores and retrieves secret data with encryption' do
      manager.set(test_key, test_data, is_secret: true)
      result = manager.get(test_key)
      expect(result).to eq(test_data)
    end

    it 'returns nil for non-existent keys' do
      result = manager.get('non_existent_key')
      expect(result).to be_nil
    end

    it 'handles TTL expiration' do
      # Use a very short TTL for testing
      short_ttl_config = cache_config.merge(ttl: 1)
      short_manager = Lall::CacheManager.new(short_ttl_config)
      
      short_manager.set(test_key, test_data, is_secret: false)
      expect(short_manager.get(test_key)).to eq(test_data)
      
      # Wait for TTL to expire
      sleep(2)
      expect(short_manager.get(test_key)).to be_nil
    end
  end

  describe '#delete' do
    let(:manager) { Lall::CacheManager.new(cache_config) }
    let(:test_key) { 'test_environment' }
    let(:test_data) { { 'configs' => { 'api_token' => 'secret123' } } }

    it 'deletes existing cache entries' do
      manager.set(test_key, test_data, is_secret: false)
      expect(manager.get(test_key)).to eq(test_data)
      
      manager.delete(test_key)
      expect(manager.get(test_key)).to be_nil
    end

    it 'handles deletion of non-existent keys gracefully' do
      expect { manager.delete('non_existent_key') }.not_to raise_error
    end
  end

  describe '#clear_cache' do
    let(:manager) { Lall::CacheManager.new(cache_config) }

    it 'clears all cache entries' do
      manager.set('key1', { data: 'value1' }, is_secret: false)
      manager.set('key2', { data: 'value2' }, is_secret: true)
      
      expect(manager.get('key1')).not_to be_nil
      expect(manager.get('key2')).not_to be_nil
      
      manager.clear_cache
      
      expect(manager.get('key1')).to be_nil
      expect(manager.get('key2')).to be_nil
    end
  end

  describe '#stats' do
    let(:manager) { Lall::CacheManager.new(cache_config) }

    it 'returns cache statistics' do
      stats = manager.stats
      expect(stats).to include(
        backend: 'moneta',
        enabled: true,
        ttl: 60,
        cache_prefix: 'lall-cache',
        cache_dir: test_cache_dir
      )
    end
  end

  describe 'encryption' do
    let(:manager) { Lall::CacheManager.new(cache_config) }
    let(:test_key) { 'secret_env' }
    let(:secret_data) { { 'database_password' => 'super_secret_password_123' } }

    it 'encrypts secret data on disk' do
      manager.set(test_key, secret_data, is_secret: true)
      
      # Find the cache file with the hashed key name
      cache_files = Dir[File.join(test_cache_dir, '*')].reject { |f| f.include?('secret.key') }
      expect(cache_files).not_to be_empty
      
      # Read the raw file contents
      cache_file_path = cache_files.first
      raw_contents = File.read(cache_file_path)
      
      # The raw contents should contain encrypted data marker
      expect(raw_contents).to include('"encrypted":true')
      expect(raw_contents).not_to include('super_secret_password_123')
      
      # But we should be able to retrieve the original data
      retrieved_data = manager.get(test_key)
      expect(retrieved_data).to eq(secret_data)
    end

    it 'does not encrypt non-secret data' do
      non_secret_data = { 'app_name' => 'my_application' }
      manager.set(test_key, non_secret_data, is_secret: false)
      
      # Find the cache file with the hashed key name
      cache_files = Dir[File.join(test_cache_dir, '*')].reject { |f| f.include?('secret.key') }
      expect(cache_files).not_to be_empty
      
      # Read the raw file contents
      cache_file_path = cache_files.first
      raw_contents = File.read(cache_file_path)
      
      # Non-secret data should be stored as plain JSON
      expect(raw_contents).to include('"encrypted":false')
      expect(raw_contents).to include('my_application')
    end
  end

  describe 'cache prefix functionality' do
    let(:cache1) { Lall::CacheManager.new(cache_config) }
    let(:cache2) { Lall::CacheManager.new(cache_config.merge(cache_prefix: 'test-app')) }

    it 'uses different cache keys for different prefixes' do
      cache1.set('same_key', 'value1')
      cache2.set('same_key', 'value2')

      expect(cache1.get('same_key')).to eq('value1')
      expect(cache2.get('same_key')).to eq('value2')
    end

    it 'clears only keys with matching prefix' do
      cache1.set('test1', 'value1')
      cache1.set('test2', 'value2')
      cache2.set('test1', 'other_value1')
      cache2.set('test2', 'other_value2')

      cache1.clear_cache

      expect(cache1.get('test1')).to be_nil
      expect(cache1.get('test2')).to be_nil
      expect(cache2.get('test1')).to eq('other_value1')
      expect(cache2.get('test2')).to eq('other_value2')
    end

    it 'includes prefix in stats' do
      expect(cache1.stats[:cache_prefix]).to eq('lall-cache')
      expect(cache2.stats[:cache_prefix]).to eq('test-app')
    end
  end

  describe '#purge_entity' do
    let(:manager) { described_class.instance(cache_config) }
    let(:environment) { Lotus::Environment.new('test-env', space: 'prod', region: 'use1', application: 'greenhouse') }
    let(:group) { Lotus::Group.new('test-group', space: 'prod', region: 'use1', application: 'greenhouse') }

    before do
      # Set up some test data in cache
      manager.set_entity_data(environment, { 'configs' => { 'key' => 'value' } })
      manager.set_entity_data(group, { 'configs' => { 'group_key' => 'group_value' } })
      
      # Set up some secret cache entries (simulate KeySearcher secret caching)
      manager.set('ENV-SECRET.test-env.prod.use1.secret1', 'secret_value1', is_secret: true)
      manager.set('ENV-SECRET.test-env.prod.use1.secret2', 'secret_value2', is_secret: true)
      manager.set('GROUP-SECRET.test-group.prod.use1.group_secret1', 'group_secret_value1', is_secret: true)
      manager.set('GROUP-SECRET.test-group.prod.use1.group_secret2', 'group_secret_value2', is_secret: true)
      
      # Add some unrelated cache entries that should not be affected
      manager.set('ENV-SECRET.other-env.prod.use1.secret1', 'other_secret_value', is_secret: true)
      manager.set('GROUP-SECRET.other-group.prod.use1.secret1', 'other_group_secret', is_secret: true)
    end

    context 'when purging environment entries' do
      it 'removes all cache entries related to the environment' do
        # Verify entries exist before purging
        expect(manager.get_entity_data(environment)).to be_truthy
        expect(manager.get('ENV-SECRET.test-env.prod.use1.secret1')).to eq('secret_value1')
        expect(manager.get('ENV-SECRET.test-env.prod.use1.secret2')).to eq('secret_value2')
        
        # Purge environment entries
        result = manager.purge_entity(environment)
        expect(result).to be true
        
        # Verify environment entries are removed
        expect(manager.get_entity_data(environment)).to be_nil
        expect(manager.get('ENV-SECRET.test-env.prod.use1.secret1')).to be_nil
        expect(manager.get('ENV-SECRET.test-env.prod.use1.secret2')).to be_nil
        
        # Verify unrelated entries are not affected
        expect(manager.get_entity_data(group)).to be_truthy
        expect(manager.get('GROUP-SECRET.test-group.prod.use1.group_secret1')).to eq('group_secret_value1')
        expect(manager.get('ENV-SECRET.other-env.prod.use1.secret1')).to eq('other_secret_value')
      end
    end

    context 'when purging group entries' do
      it 'removes all cache entries related to the group' do
        # Verify entries exist before purging
        expect(manager.get_entity_data(group)).to be_truthy
        expect(manager.get('GROUP-SECRET.test-group.prod.use1.group_secret1')).to eq('group_secret_value1')
        expect(manager.get('GROUP-SECRET.test-group.prod.use1.group_secret2')).to eq('group_secret_value2')
        
        # Purge group entries
        result = manager.purge_entity(group)
        expect(result).to be true
        
        # Verify group entries are removed
        expect(manager.get_entity_data(group)).to be_nil
        expect(manager.get('GROUP-SECRET.test-group.prod.use1.group_secret1')).to be_nil
        expect(manager.get('GROUP-SECRET.test-group.prod.use1.group_secret2')).to be_nil
        
        # Verify unrelated entries are not affected
        expect(manager.get_entity_data(environment)).to be_truthy
        expect(manager.get('ENV-SECRET.test-env.prod.use1.secret1')).to eq('secret_value1')
        expect(manager.get('GROUP-SECRET.other-group.prod.use1.secret1')).to eq('other_group_secret')
      end
    end

    context 'when cache is disabled' do
      let(:disabled_manager) { described_class.instance({ enabled: false }) }

      it 'returns false for environment purge' do
        result = disabled_manager.purge_entity(environment)
        expect(result).to be false
      end

      it 'returns false for group purge' do
        result = disabled_manager.purge_entity(group)
        expect(result).to be false
      end
    end

    context 'with invalid entity type' do
      it 'raises ArgumentError for unsupported entity types' do
        expect { manager.purge_entity("invalid") }.to raise_error(ArgumentError, /Unsupported entity type/)
        expect { manager.purge_entity(123) }.to raise_error(ArgumentError, /Unsupported entity type/)
      end
    end
  end

  describe 'entity clear_cache methods' do
    let(:manager) { described_class.instance(cache_config) }
    let(:environment) { Lotus::Environment.new('test-env') }
    let(:group) { Lotus::Group.new('test-group') }

    it 'environment clear_cache calls purge_entity' do
      allow(manager).to receive(:purge_entity).with(environment)
      environment.clear_cache
      expect(manager).to have_received(:purge_entity).with(environment)
    end

    it 'group clear_cache calls purge_entity' do
      allow(manager).to receive(:purge_entity).with(group)
      group.clear_cache
      expect(manager).to have_received(:purge_entity).with(group)
    end
  end
end
