# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Runner do
  describe '.fetch_yaml' do
    let(:mock_environment) { instance_double(Lotus::Environment) }
    
    before do
      allow(mock_environment).to receive(:lotus_cmd).and_return('lotus view -s \\test-env -e \\test-env -a greenhouse -G')
      allow(Open3).to receive(:popen3).and_yield(
        double('stdin'),
        double('stdout', read: "group: test\nconfigs:\n  key: value"),
        double('stderr', read: ''),
        double('wait_thr', value: double('status', success?: true))
      )
    end

    it 'constructs correct lotus command using entity.lotus_cmd' do
      expect(Open3).to receive(:popen3).with('lotus view -s \\test-env -e \\test-env -a greenhouse -G')
      Lotus::Runner.fetch_yaml(mock_environment)
    end

    it 'parses YAML output' do
      result = Lotus::Runner.fetch_yaml(mock_environment)
      expect(result).to be_a(Hash)
      expect(result['group']).to eq('test')
    end

    it 'returns nil on command failure' do
      allow(mock_environment).to receive(:name).and_return('test-env')
      allow(Open3).to receive(:popen3).and_yield(
        double('stdin'),
        double('stdout', read: ''),
        double('stderr', read: 'Error message'),
        double('wait_thr', value: double('status', success?: false))
      )

      result = Lotus::Runner.fetch_yaml(mock_environment)
      expect(result).to be_nil
    end
  end

  describe '.fetch' do
    let(:mock_environment) { instance_double(Lotus::Environment) }
    let(:mock_cache_manager) { instance_double(Lall::CacheManager) }
    
    before do
      allow(Lotus::Runner).to receive(:cache_manager).and_return(mock_cache_manager)
      allow(Lotus::Runner).to receive(:cached_data_for_entity).and_return(nil)
      allow(Lotus::Runner).to receive(:fetch_yaml).and_return({ 'group' => 'test', 'configs' => { 'key' => 'value' } })
      allow(mock_environment).to receive(:lotus_parse).and_return({ 'group' => 'test', 'configs' => { 'key' => 'value' } })
      allow(Lotus::Runner).to receive(:set_cached_data_for_entity)
      allow(mock_environment).to receive(:instance_variable_set)
    end

    it 'returns cached data if available' do
      cached_data = { 'group' => 'cached', 'configs' => {} }
      allow(Lotus::Runner).to receive(:cached_data_for_entity).and_return(cached_data)
      
      result = Lotus::Runner.fetch(mock_environment)
      expect(result).to eq(cached_data)
      expect(mock_environment).to have_received(:instance_variable_set).with(:@data, cached_data)
    end

    it 'fetches and parses data on cache miss' do
      result = Lotus::Runner.fetch(mock_environment)
      expect(result).to eq({ 'group' => 'test', 'configs' => { 'key' => 'value' } })
      expect(Lotus::Runner).to have_received(:fetch_yaml).with(mock_environment)
      expect(mock_environment).to have_received(:lotus_parse)
    end

    it 'caches the parsed result' do
      Lotus::Runner.fetch(mock_environment)
      expect(Lotus::Runner).to have_received(:set_cached_data_for_entity).with(mock_environment, mock_cache_manager, { 'group' => 'test', 'configs' => { 'key' => 'value' } })
    end

    it 'returns nil if fetch_yaml fails' do
      allow(Lotus::Runner).to receive(:fetch_yaml).and_return(nil)
      
      result = Lotus::Runner.fetch(mock_environment)
      expect(result).to be_nil
    end
  end

  describe '.fetch_all' do
    let(:env1) { instance_double(Lotus::Environment) }
    let(:env2) { instance_double(Lotus::Environment) }
    
    it 'returns empty array for empty input' do
      result = Lotus::Runner.fetch_all([])
      expect(result).to eq([])
    end

    it 'fetches all entities in parallel' do
      entities = [env1, env2]
      allow(Lotus::Runner).to receive(:fetch).and_return({ 'data' => 'test' })
      
      result = Lotus::Runner.fetch_all(entities)
      
      expect(result).to eq(entities)
      expect(Lotus::Runner).to have_received(:fetch).with(env1)
      expect(Lotus::Runner).to have_received(:fetch).with(env2)
    end
  end

  describe '.ping' do
    it 'constructs correct ping command with environment space' do
      env = double('environment', space: 'test-space')
      expect(Lotus::Runner).to receive(:system).with('lotus ping -s \\test-space > /dev/null 2>&1')

      Lotus::Runner.ping(env)
    end

    it 'defaults to prod space for string environments' do
      expect(Lotus::Runner).to receive(:system).with('lotus ping -s \\prod > /dev/null 2>&1')

      Lotus::Runner.ping('test-env-string')
    end

    it 'returns system command result' do
      allow(Lotus::Runner).to receive(:system).and_return(true)

      result = Lotus::Runner.ping('test-env')
      expect(result).to be true
    end
  end
end
