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
        allow(settings).to receive(:respond_to?).with(:cache_settings).and_return(true)
        
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
          expect(env.entity_set).to eq(entity_set)
          expect(env.application).to eq('greenhouse') # default application
        end
      end

      it 'stores the settings in the entity set' do
        entity_set = described_class.new(settings)
        expect(entity_set.settings).to eq(settings)
      end

      
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

  describe '#all' do
    it 'returns all entities' do
      entities = [double('entity1'), double('entity2')]
      entity_set = described_class.new(entities)
      
      expect(entity_set.all).to eq(entities)
    end
  end

  describe '#environments' do
    it 'returns only Environment entities' do
      env1 = Lotus::Environment.new('env1')
      env2 = Lotus::Environment.new('env2')
      group = Lotus::Group.new('group1')
      
      entity_set = described_class.new([env1, group, env2])
      
      environments = entity_set.environments
      expect(environments).to contain_exactly(env1, env2)
      expect(environments.all? { |e| e.is_a?(Lotus::Environment) }).to be true
    end

    it 'returns empty array when no environments exist' do
      group = Lotus::Group.new('group1')
      entity_set = described_class.new([group])
      
      expect(entity_set.environments).to eq([])
    end
  end

  describe '#groups' do
    it 'returns only Group entities' do
      env = Lotus::Environment.new('env1')
      group1 = Lotus::Group.new('group1')
      group2 = Lotus::Group.new('group2')
      
      entity_set = described_class.new([env, group1, group2])
      
      groups = entity_set.groups
      expect(groups).to contain_exactly(group1, group2)
      expect(groups.all? { |g| g.is_a?(Lotus::Group) }).to be true
    end

    it 'returns empty array when no groups exist' do
      env = Lotus::Environment.new('env1')
      entity_set = described_class.new([env])
      
      expect(entity_set.groups).to eq([])
    end
  end

  describe '#fetch_all' do
    let(:settings) { double('SettingsManager') }
    
    before do
      allow(settings).to receive(:groups).and_return({
        'group1' => ['env1', 'env2'],
        'group2' => ['env3']
      })
      allow(settings).to receive(:instance_variable_get).with(:@cli_options).and_return({})
      allow(settings).to receive(:cache_settings).and_return({ enabled: false })
    end

    it 'fetches all environments and creates groups from their data' do
      entity_set = described_class.new(settings)
      
      # Mock Lotus::Runner.fetch_all to be called at least once
      expect(Lotus::Runner).to receive(:fetch_all).at_least(:once) do |entities|
        # Simulate populating environment data with group references
        entities.each do |entity|
          if entity.is_a?(Lotus::Environment)
            entity.instance_variable_set(:@data, { 'group' => 'test-group', 'configs' => {} })
          end
        end
        entities
      end

      result = entity_set.fetch_all
      
      expect(result).to eq(entity_set)
      expect(entity_set.environments.length).to be > 0
      expect(entity_set.groups.length).to be > 0
    end

    it 'handles environments without group data' do
      entity_set = described_class.new(settings)
      
      # Mock Lotus::Runner.fetch_all to return environments without group data
      expect(Lotus::Runner).to receive(:fetch_all).once do |entities|
        entities.each do |entity|
          if entity.is_a?(Lotus::Environment)
            entity.instance_variable_set(:@data, { 'configs' => {} }) # No group field
          end
        end
        entities
      end

      result = entity_set.fetch_all
      
      expect(result).to eq(entity_set)
      expect(entity_set.environments.length).to be > 0
      expect(entity_set.groups.length).to eq(0) # No groups should be created
    end
  end
end
