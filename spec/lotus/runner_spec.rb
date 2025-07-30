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
    before do
      allow(Open3).to receive(:popen3).and_yield(
        double('stdin'),
        double('stdout', read: "group: test\nconfigs:\n  key: value"),
        double('stderr', read: ''),
        double('wait_thr', value: double('status', success?: true))
      )
    end

    it 'constructs correct lotus command' do
      expect(Open3).to receive(:popen3).with(/lotus view -s \\test-env -e \\test-env -a greenhouse -G/)
      Lotus::Runner.fetch_yaml('test-env')
    end

    it 'includes region argument when applicable' do
      allow(Lotus::Runner).to receive(:get_lotus_args).and_return(%w[prod use1])
      expect(Open3).to receive(:popen3).with(/lotus view -s \\prod -e \\test-env -a greenhouse -G -r \\use1/)
      Lotus::Runner.fetch_yaml('test-env')
    end

    it 'parses YAML output' do
      result = Lotus::Runner.fetch_yaml('test-env')
      expect(result).to be_a(Hash)
      expect(result['group']).to eq('test')
    end

    it 'returns nil on command failure' do
      allow(Open3).to receive(:popen3).and_yield(
        double('stdin'),
        double('stdout', read: ''),
        double('stderr', read: 'Error message'),
        double('wait_thr', value: double('status', success?: false))
      )

      result = Lotus::Runner.fetch_yaml('test-env')
      expect(result).to be_nil
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
