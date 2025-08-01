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

  after do
    FileUtils.rm_rf(test_cache_dir) if Dir.exist?(test_cache_dir)
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
end
