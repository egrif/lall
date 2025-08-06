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

  describe '#secrets' do
    context 'with loaded data' do
      it 'returns array of secret keys' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, yaml_hash)
        expect(group.secrets).to eq(%w[secret_key api_secret])
      end

      it 'returns empty array when secrets is missing' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, {})
        expect(group.secrets).to eq([])
      end

      it 'returns empty array when secrets.keys is missing' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, { 'secrets' => {} })
        expect(group.secrets).to eq([])
      end

      it 'handles non-array secrets.keys' do
        group = Lotus::Group.new('test-group')
        group.instance_variable_set(:@data, { 'secrets' => { 'keys' => 'single_key' } })
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
    let(:group) { Lotus::Group.new('test-group') }

    it 'delegates to Lotus::Runner.fetch' do
      expect(Lotus::Runner).to receive(:fetch).with(group).and_return(yaml_hash)
      
      result = group.fetch
      expect(result).to eq(yaml_hash)
    end

    it 'returns cached data if already loaded' do
      group.instance_variable_set(:@data, yaml_hash)
      
      expect(Lotus::Runner).not_to receive(:fetch)
      result = group.fetch
      
      expect(result).to eq(yaml_hash)
    end
  end

  describe '#lotus_cmd' do
    it 'constructs correct lotus command' do
      group = Lotus::Group.new('test-group', space: 'prod', region: 'use1')
      expected_cmd = 'lotus view -s \\prod -r \\use1 -a greenhouse -g \\test-group'
      expect(group.lotus_cmd).to eq(expected_cmd)
    end

    it 'handles group without explicit space/region' do
      group = Lotus::Group.new('test-group')
      expected_cmd = 'lotus view -s \\ -r \\ -a greenhouse -g \\test-group'
      expect(group.lotus_cmd).to eq(expected_cmd)
    end
  end

  describe '#lotus_parse' do
    let(:group) { Lotus::Group.new('test-group') }

    it 'returns the raw data as-is' do
      result = group.lotus_parse(yaml_hash)
      expect(result).to eq(yaml_hash)
    end
  end
end
