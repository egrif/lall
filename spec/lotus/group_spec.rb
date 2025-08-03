# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Group do
  let(:yaml_hash) do
    {
      'configs' => {
        'database_url' => 'postgres://localhost:5432/test',
        'api_token' => 'abc123'
      },
      'secrets' => {
        'keys' => %w[secret_key api_secret]
      }
    }
  end

  let(:cache_manager) { instance_double(Lall::CacheManager) }

  # Reset singleton state before each test
  before do
    Lall::CacheManager.reset!
  end

  after do
    Lall::CacheManager.reset!
  end

  describe '#initialize' do
    context 'with yaml hash (legacy)' do
      it 'stores the yaml hash data' do
        group = Lotus::Group.new(yaml_hash)
        expect(group.data).to eq(yaml_hash)
      end

      it 'sets application to default greenhouse' do
        group = Lotus::Group.new(yaml_hash)
        expect(group.application).to eq('greenhouse')
      end

      it 'accepts custom application' do
        group = Lotus::Group.new(yaml_hash, application: 'custom-app')
        expect(group.application).to eq('custom-app')
      end

      it 'accepts cache manager' do
        group = Lotus::Group.new(yaml_hash, cache_manager: cache_manager)
        expect(group.instance_variable_get(:@cache_manager)).to eq(cache_manager)
      end
    end

    context 'with group name (new)' do
      it 'stores the group name' do
        group = Lotus::Group.new('test-group')
        expect(group.name).to eq('test-group')
        expect(group.data).to be_nil
      end

      it 'sets application to default greenhouse' do
        group = Lotus::Group.new('test-group')
        expect(group.application).to eq('greenhouse')
      end

      it 'accepts custom application' do
        group = Lotus::Group.new('test-group', application: 'custom-app')
        expect(group.application).to eq('custom-app')
      end

      it 'accepts cache manager' do
        group = Lotus::Group.new('test-group', cache_manager: cache_manager)
        expect(group.instance_variable_get(:@cache_manager)).to eq(cache_manager)
      end
    end
  end

  describe '.from_args' do
    it 'creates group with specified name and application' do
      group = described_class.from_args(group: 'test-group', application: 'custom-app')
      expect(group.name).to eq('test-group')
      expect(group.application).to eq('custom-app')
    end

    it 'uses default greenhouse application' do
      group = described_class.from_args(group: 'test-group')
      expect(group.application).to eq('greenhouse')
    end

    it 'accepts cache manager' do
      group = described_class.from_args(group: 'test-group', cache_manager: cache_manager)
      expect(group.instance_variable_get(:@cache_manager)).to eq(cache_manager)
    end
  end

  describe '#configs' do
    context 'with loaded data' do
      it 'returns the configs hash' do
        group = Lotus::Group.new(yaml_hash)
        expect(group.configs).to eq(yaml_hash['configs'])
      end

      it 'returns empty hash when configs is missing' do
        group = Lotus::Group.new({})
        expect(group.configs).to eq({})
      end
    end

    context 'without loaded data' do
      it 'raises NoMethodError when data is nil' do
        group = Lotus::Group.new('test-group')
        expect { group.configs }.to raise_error(NoMethodError, /requires data to be loaded first/)
      end
    end
  end

  describe '#secrets' do
    context 'with loaded data' do
      it 'returns array of secret keys' do
        group = Lotus::Group.new(yaml_hash)
        expect(group.secrets).to eq(%w[secret_key api_secret])
      end

      it 'returns empty array when secrets is missing' do
        group = Lotus::Group.new({})
        expect(group.secrets).to eq([])
      end

      it 'returns empty array when secrets.keys is missing' do
        group = Lotus::Group.new({ 'secrets' => {} })
        expect(group.secrets).to eq([])
      end

      it 'handles non-array secrets.keys' do
        group = Lotus::Group.new({ 'secrets' => { 'keys' => 'single_key' } })
        expect(group.secrets).to eq(['single_key'])
      end
    end

    context 'without loaded data' do
      it 'raises NoMethodError when data is nil' do
        group = Lotus::Group.new('test-group')
        expect { group.secrets }.to raise_error(NoMethodError, /requires data to be loaded first/)
      end
    end
  end

  describe '#fetch' do
    let(:group) { Lotus::Group.new('test-group', cache_manager: cache_manager) }

    context 'when data is already loaded' do
      it 'returns existing data without fetching' do
        group.instance_variable_set(:@data, yaml_hash)
        expect(Lotus::Runner).not_to receive(:fetch_group_yaml)
        
        result = group.fetch
        expect(result).to eq(yaml_hash)
      end
    end

    context 'with cache manager' do
      context 'cache hit' do
        it 'returns cached data' do
          expect(cache_manager).to receive(:get_group_data).with('test-group', 'greenhouse').and_return(yaml_hash)
          expect(Lotus::Runner).not_to receive(:fetch_group_yaml)
          
          result = group.fetch
          expect(result).to eq(yaml_hash)
          expect(group.data).to eq(yaml_hash)
        end
      end

      context 'cache miss' do
        it 'fetches from lotus and caches result' do
          expect(cache_manager).to receive(:get_group_data).with('test-group', 'greenhouse').and_return(nil)
          expect(Lotus::Runner).to receive(:fetch_group_yaml).with(nil, 'test-group').and_return(yaml_hash)
          expect(cache_manager).to receive(:set_group_data).with('test-group', 'greenhouse', yaml_hash)
          
          result = group.fetch
          expect(result).to eq(yaml_hash)
          expect(group.data).to eq(yaml_hash)
        end

        it 'returns nil when lotus fetch fails' do
          expect(cache_manager).to receive(:get_group_data).with('test-group', 'greenhouse').and_return(nil)
          expect(Lotus::Runner).to receive(:fetch_group_yaml).with(nil, 'test-group').and_return(nil)
          expect(cache_manager).not_to receive(:set_group_data)
          
          result = group.fetch
          expect(result).to be_nil
          expect(group.data).to be_nil
        end
      end
    end

    context 'without cache manager' do
      let(:group) { 
        require_relative '../../lib/lall/cli'
        Lotus::Group.new('test-group', cache_manager: LallCLI::NullCacheManager.new) 
      }

      it 'fetches from lotus directly and does not cache' do
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with(nil, 'test-group').and_return(yaml_hash)
        
        result = group.fetch
        expect(result).to eq(yaml_hash)
        expect(group.data).to eq(yaml_hash)
      end

      it 'returns nil when lotus fetch fails' do
        expect(Lotus::Runner).to receive(:fetch_group_yaml).with(nil, 'test-group').and_return(nil)
        
        result = group.fetch
        expect(result).to be_nil
        expect(group.data).to be_nil
      end
    end
  end
end
