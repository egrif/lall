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

    context 'with name:space:region format' do
      it 'parses just the name' do
        env = Lotus::Environment.new('prod-s5')
        expect(env.name).to eq('prod-s5')
        expect(env.space).to eq('prod') # default from name
        expect(env.region).to eq('use1')
      end

      it 'parses name and space' do
        env = Lotus::Environment.new('prod-s5:custom-space')
        expect(env.name).to eq('prod-s5')
        expect(env.space).to eq('custom-space')
        expect(env.region).to eq('use1')
      end

      it 'parses name, space, and region' do
        env = Lotus::Environment.new('prod-s5:custom-space:use1')
        expect(env.name).to eq('prod-s5')
        expect(env.space).to eq('custom-space')
        expect(env.region).to eq('use1')
      end

      it 'parses name and region with empty space' do
        env = Lotus::Environment.new('prod-s5::use1')
        expect(env.name).to eq('prod-s5')
        expect(env.space).to eq('prod') # default from name
        expect(env.region).to eq('use1')
      end

      it 'handles trailing colon' do
        env = Lotus::Environment.new('prod-s5:')
        expect(env.name).to eq('prod-s5')
        expect(env.space).to eq('prod') # default from name
        expect(env.region).to eq('use1')
      end
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

  # Note: fetch method has been moved to Lotus::Runner - entities no longer have fetch method
  # Data loading is handled through Lotus::Runner.fetch(entity) or EntitySet.fetch_all

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

    it 'sets @data and instantiates secrets' do
      env.lotus_parse(raw_data)
      expect(env.data).to eq(raw_data)
      expect(env.secrets).to be_an(Array)
      # Should have instantiated secret objects for each key
      expect(env.secrets.length).to eq(1)
      expect(env.secrets.first).to be_a(Lotus::Secret)
      expect(env.secrets.first.name).to eq('api_key')
    end
  end

  # Note: fetch_secrets method has been eliminated
  # Secret fetching is now handled through EntitySet.fetch_all and Entity.matched_secrets
end
