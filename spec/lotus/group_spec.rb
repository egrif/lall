# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Group do
  let(:yaml_hash) do
    {
      'configs' => {
        'database_url' => 'postgres://localhost:5432/test',
        'api_token' => 'abc123'
      },
      'group_secrets' => {
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
    it 'stores the group name' do
      group = Lotus::Group.new('test-group')
      expect(group.name).to eq('test-group')
      expect(group.data).to be_nil
      expect(group.application).to eq('greenhouse')
    end

    it 'accepts custom application' do
      group = Lotus::Group.new('test-group', application: 'custom-app')
      expect(group.application).to eq('custom-app')
    end

    it 'accepts space and region parameters' do
      group = Lotus::Group.new('test-group', space: 'prod', region: 'use1')
      expect(group.space).to eq('prod')
      expect(group.region).to eq('use1')
    end

    it 'accepts parent parameter' do
      parent = double('EntitySet')
      group = Lotus::Group.new('test-group', parent: parent)
      expect(group.instance_variable_get(:@parent_entity)).to eq(parent)
    end
  end

  describe '#configs' do
    context 'with loaded data' do
      it 'returns the configs hash' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, yaml_hash)
        expect(group.configs).to eq(yaml_hash['configs'])
      end

      it 'returns empty hash when configs is missing' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, {})
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

  describe '#secret_keys' do
    context 'with loaded data' do
      it 'returns array of secret keys' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, yaml_hash)
        expect(group.secret_keys).to eq(%w[secret_key api_secret])
      end

      it 'returns empty array when secrets is missing' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, {})
        expect(group.secret_keys).to eq([])
      end

      it 'returns empty array when secrets.keys is missing' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, { 'group_secrets' => {} })
        expect(group.secret_keys).to eq([])
      end

      it 'handles non-array secrets.keys' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, { 'group_secrets' => { 'keys' => 'single_key' } })
        expect(group.secret_keys).to eq(['single_key'])
      end
    end

    context 'without loaded data' do
      it 'raises NoMethodError when data is nil' do
        group = Lotus::Group.new('test-group')
        expect { group.secret_keys }.to raise_error(NoMethodError, /requires data to be loaded first/)
      end
    end
  end

  describe '#secrets' do
    context 'with loaded data' do
      it 'returns array of Secret objects after instantiation' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, yaml_hash)
        group.send(:instantiate_secrets)
        expect(group.secrets).to be_an(Array)
        expect(group.secrets.length).to eq(2)
        expect(group.secrets.all? { |s| s.is_a?(Lotus::Secret) }).to be true
        expect(group.secrets.map(&:name)).to contain_exactly('secret_key', 'api_secret')
      end

      it 'returns empty array when no secrets instantiated' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, yaml_hash)
        expect(group.secrets).to eq([])
      end
    end

    context 'without loaded data' do
      it 'returns empty array when data is nil' do
        group = Lotus::Group.new('test-group')
        expect(group.secrets).to eq([])
      end
    end
  end

  # Note: fetch method has been moved to Lotus::Runner - entities no longer have fetch method
  # Data loading is handled through Lotus::Runner.fetch(entity) or EntitySet.fetch_all

  describe '#lotus_cmd' do
    it 'constructs correct lotus command' do
      group = Lotus::Group.new('test-group', space: 'prod', region: 'use1')
      expected_cmd = 'lotus view -s prod -r use1 -a greenhouse -g test-group'
      expect(group.lotus_cmd).to eq(expected_cmd)
    end

    it 'handles group without explicit space/region' do
      group = Lotus::Group.new('test-group')
      expected_cmd = 'lotus view -s  -r  -a greenhouse -g test-group'
      expect(group.lotus_cmd).to eq(expected_cmd)
    end
  end

  describe '#lotus_parse' do
    let(:group) { Lotus::Group.new('test-group') }

    it 'sets @data and instantiates secrets' do
      group.lotus_parse(yaml_hash)
      expect(group.data).to eq(yaml_hash)
      expect(group.secrets).to be_an(Array)
      # Should have instantiated secret objects for each key
      expect(group.secrets.length).to eq(2)
      expect(group.secrets.all? { |s| s.is_a?(Lotus::Secret) }).to be true
      expect(group.secrets.map(&:name)).to contain_exactly('secret_key', 'api_secret')
    end
  end
end
