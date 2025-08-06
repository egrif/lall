# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Runner do
  describe '.get_lotus_args' do
    context 'with production environments' do
      it 'returns prod as s_arg for prod environments' do
        s_arg, r_arg = Lotus::Runner.get_lotus_args('prod')
        expect(s_arg).to eq('prod')
        expect(r_arg).to be_nil
      end

      it 'returns prod as s_arg for staging environments' do
        s_arg, = Lotus::Runner.get_lotus_args('staging-s2')
        expect(s_arg).to eq('prod')
      end
    end

    context 'with numbered environments' do
      it 'sets r_arg to use1 for s1-s99' do
        s_arg, r_arg = Lotus::Runner.get_lotus_args('prod-s5')
        expect(s_arg).to eq('prod')
        expect(r_arg).to eq('use1')
      end

      it 'sets r_arg to euc1 for s101-s199' do
        s_arg, r_arg = Lotus::Runner.get_lotus_args('prod-s150')
        expect(s_arg).to eq('prod')
        expect(r_arg).to eq('euc1')
      end

      it 'sets r_arg to apse2 for s201-s299' do
        s_arg, r_arg = Lotus::Runner.get_lotus_args('prod-s250')
        expect(s_arg).to eq('prod')
        expect(r_arg).to eq('apse2')
      end

      it 'sets r_arg to nil for numbers outside valid ranges' do
        s_arg, r_arg = Lotus::Runner.get_lotus_args('prod-s300')
        expect(s_arg).to eq('prod')
        expect(r_arg).to be_nil
      end
    end

    context 'with other environments' do
      it 'uses environment name as s_arg' do
        s_arg, r_arg = Lotus::Runner.get_lotus_args('development')
        expect(s_arg).to eq('development')
        expect(r_arg).to be_nil
      end
    end
  end

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

  describe '.secret_get' do
    context 'without group' do
      before do
        allow(Open3).to receive(:popen3).and_yield(
          double('stdin'),
          double('stdout', read: 'SECRET_KEY=secret_value'),
          double('stderr', read: ''),
          double('wait_thr', value: double('status', success?: true))
        )
      end

      it 'constructs correct lotus command' do
        expect(Open3).to receive(:popen3).with(/lotus secret get test_key -s \\test-env -e \\test-env -a greenhouse/)
        Lotus::Runner.secret_get('test-env', 'test_key')
      end

      it 'extracts value from KEY=value format' do
        result = Lotus::Runner.secret_get('test-env', 'test_key')
        expect(result).to eq('secret_value')
      end
    end

    context 'with group' do
      before do
        allow(Open3).to receive(:popen3).and_yield(
          double('stdin'),
          double('stdout', read: 'GROUP_SECRET=group_value'),
          double('stderr', read: ''),
          double('wait_thr', value: double('status', success?: true))
        )
      end

      it 'uses group instead of environment' do
        expect(Open3).to receive(:popen3).with(/lotus secret get test_key -s \\test-env -g \\test-group -a greenhouse/)
        Lotus::Runner.secret_get('test-env', 'test_key', group: 'test-group')
      end
    end

    context 'with region' do
      before do
        allow(Lotus::Runner).to receive(:get_lotus_args).and_return(%w[prod use1])
        allow(Open3).to receive(:popen3).and_yield(
          double('stdin'),
          double('stdout', read: 'SECRET_KEY=secret_value'),
          double('stderr', read: ''),
          double('wait_thr', value: double('status', success?: true))
        )
      end

      it 'includes region argument' do
        expect(Open3).to receive(:popen3).with(/lotus secret get test_key -s \\prod -e \\test-env -a greenhouse  -r \\use1/)
        Lotus::Runner.secret_get('test-env', 'test_key')
      end
    end

    it 'returns nil on command failure' do
      allow(Open3).to receive(:popen3).and_yield(
        double('stdin'),
        double('stdout', read: ''),
        double('stderr', read: 'Error message'),
        double('wait_thr', value: double('status', success?: false))
      )

      result = Lotus::Runner.secret_get('test-env', 'test_key')
      expect(result).to be_nil
    end

    it 'handles output without equals sign' do
      allow(Open3).to receive(:popen3).and_yield(
        double('stdin'),
        double('stdout', read: 'plain_secret_value'),
        double('stderr', read: ''),
        double('wait_thr', value: double('status', success?: true))
      )

      result = Lotus::Runner.secret_get('test-env', 'test_key')
      expect(result).to eq('plain_secret_value')
    end
  end

  describe '.secret_get_many' do
    it 'fetches multiple secrets in parallel' do
      allow(Lotus::Runner).to receive(:secret_get).with('test-env', 'key1').and_return('value1')
      allow(Lotus::Runner).to receive(:secret_get).with('test-env', 'key2').and_return('value2')

      results = Lotus::Runner.secret_get_many('test-env', %w[key1 key2])

      expect(results).to eq({ 'key1' => 'value1', 'key2' => 'value2' })
    end

    it 'handles failed secret fetches' do
      allow(Lotus::Runner).to receive(:secret_get).with('test-env', 'key1').and_return('value1')
      allow(Lotus::Runner).to receive(:secret_get).with('test-env', 'key2').and_return(nil)

      results = Lotus::Runner.secret_get_many('test-env', %w[key1 key2])

      expect(results).to eq({ 'key1' => 'value1', 'key2' => nil })
    end
  end

  describe '.ping' do
    it 'constructs correct ping command' do
      allow(Lotus::Runner).to receive(:get_lotus_args).and_return(['prod', nil])
      expect(Lotus::Runner).to receive(:system).with('lotus ping -s \\prod > /dev/null 2>&1')

      Lotus::Runner.ping('prod-env')
    end

    it 'returns system command result' do
      allow(Lotus::Runner).to receive(:get_lotus_args).and_return(['test', nil])
      allow(Lotus::Runner).to receive(:system).and_return(true)

      result = Lotus::Runner.ping('test-env')
      expect(result).to be true
    end
  end
end
