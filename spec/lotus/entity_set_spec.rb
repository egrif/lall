# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/lotus/entity_set'

RSpec.describe Lotus::EntitySet do
  describe '#initialize' do
    it 'initializes with empty entities by default' do
      entity_set = described_class.new
      expect(entity_set.entities).to eq([])
      expect(entity_set.settings).to be_nil
    end

    it 'accepts entities and settings' do
      entities = [double('entity1'), double('entity2')]
      settings = double('settings')
      entity_set = described_class.new(entities, settings)
      
      expect(entity_set.entities).to eq(entities)
      expect(entity_set.settings).to eq(settings)
    end

    context 'when initialized with settings object' do
      let(:settings) { double('SettingsManager') }
      let(:cache_manager) { double('CacheManager') }
      
      let(:groups) do
        {
          'staging' => ['staging-s1', 'staging-s2'],
          'prod-us' => ['prod-s1', 'prod-s2', 'prod-s3'],
          'prod-all' => ['prod-s1', 'prod-s2', 'prod-s101'] # prod-s1, prod-s2 are duplicates
        }
      end

      let(:cache_settings) do
        {
          enabled: true,
          ttl: 3600,
          directory: '/tmp/cache',
          prefix: 'test-prefix'
        }
      end

      before do
        allow(settings).to receive(:groups).and_return(groups)
        allow(settings).to receive(:cache_settings).and_return(cache_settings)
        allow(settings).to receive(:respond_to?).with(:groups).and_return(true)
        
        # Mock the cache manager initialization
        allow(Lall::CacheManager).to receive(:new).with(cache_settings).and_return(cache_manager)
      end

      it 'creates environments from settings groups with deduplication' do
        entity_set = described_class.new(settings)
        
        # Should have 6 unique environments: staging-s1, staging-s2, prod-s1, prod-s2, prod-s3, prod-s101
        expect(entity_set.entities.length).to eq(6)
        
        environment_names = entity_set.entities.map(&:name)
        expect(environment_names).to contain_exactly(
          'staging-s1', 'staging-s2', 'prod-s1', 'prod-s2', 'prod-s3', 'prod-s101'
        )
      end

      it 'creates Environment instances with cache manager and entity_set reference' do
        entity_set = described_class.new(settings)
        
        entity_set.entities.each do |env|
          expect(env).to be_a(Lotus::Environment)
          expect(env.instance_variable_get(:@cache_manager)).to eq(cache_manager)
          expect(env.entity_set).to eq(entity_set)
          expect(env.application).to eq('greenhouse') # default application
        end
      end

      it 'stores the settings in the entity set' do
        entity_set = described_class.new(settings)
        expect(entity_set.settings).to eq(settings)
      end

      context 'when caching is disabled' do
        let(:cache_settings) { { enabled: false } }
        let(:null_cache_manager) { double('NullCacheManager') }

        before do
          allow(LallCLI::NullCacheManager).to receive(:new).and_return(null_cache_manager)
        end

        it 'uses NullCacheManager when caching is disabled' do
          entity_set = described_class.new(settings)
          
          entity_set.entities.each do |env|
            expect(env.instance_variable_get(:@cache_manager)).to eq(null_cache_manager)
          end
        end
      end
    end
  end

  describe '.from_settings' do
    # This method no longer exists, but keeping this context for clarity
    it 'no longer exists - functionality moved to initialize' do
      expect(described_class).not_to respond_to(:from_settings)
    end
  end

  describe '#add' do
    it 'adds an entity to the collection' do
      entity_set = described_class.new
      entity = double('entity')
      
      entity_set.add(entity)
      expect(entity_set.entities).to include(entity)
    end

    it 'sets entity_set reference on environments' do
      entity_set = described_class.new
      env = Lotus::Environment.new('test-env')
      
      entity_set.add(env)
      expect(env.entity_set).to eq(entity_set)
    end
  end

  describe '#remove' do
    it 'removes an entity from the collection' do
      entity = double('entity')
      entity_set = described_class.new([entity])
      
      entity_set.remove(entity)
      expect(entity_set.entities).not_to include(entity)
    end

    it 'clears entity_set reference on environments' do
      env = Lotus::Environment.new('test-env')
      entity_set = described_class.new([env])
      env.instance_variable_set(:@entity_set, entity_set)
      
      entity_set.remove(env)
      expect(env.entity_set).to be_nil
    end
  end

  describe '#find_by_name' do
    let(:env1) { Lotus::Environment.new('staging-s1') }
    let(:env2) { Lotus::Environment.new('prod-s1') }
    let(:entity_set) { described_class.new([env1, env2]) }

    it 'finds environment by name' do
      expect(entity_set.find_by_name('staging-s1')).to eq(env1)
      expect(entity_set.find_by_name('prod-s1')).to eq(env2)
      expect(entity_set.find_by_name('nonexistent')).to be_nil
    end
  end

  describe '#group_names' do
    let(:settings) { double('SettingsManager') }
    let(:env1) { Lotus::Environment.new('staging-s1') }
    let(:env2) { Lotus::Environment.new('prod-s1') }
    let(:env3) { Lotus::Environment.new('prod-s2') }
    let(:entity_set) { described_class.new([env1, env2, env3], settings) }
    
    let(:groups) do
      {
        'staging' => ['staging-s1', 'staging-s2'],
        'prod-us' => ['prod-s1', 'prod-s2'],
        'prod-eu' => ['prod-s101', 'prod-s102'] # No matching environments
      }
    end

    before do
      allow(settings).to receive(:groups).and_return(groups)
    end

    it 'returns group names that contain the environments' do
      group_names = entity_set.group_names
      expect(group_names).to contain_exactly('staging', 'prod-us')
    end

    it 'returns empty array when no settings' do
      entity_set_no_settings = described_class.new([env1, env2])
      expect(entity_set_no_settings.group_names).to eq([])
    end
  end

  describe '#all' do
    it 'returns all entities' do
      entities = [double('entity1'), double('entity2')]
      entity_set = described_class.new(entities)
      
      expect(entity_set.all).to eq(entities)
    end
  end
end
