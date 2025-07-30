# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Environment do
  let(:yaml_hash) do
    {
      'group' => 'test-group',
      'configs' => {
        'database_url' => 'postgres://localhost:5432/test',
        'api_token' => 'abc123'
      },
      'secrets' => {
        'keys' => ['secret_key', 'api_secret']
      },
      'group_secrets' => {
        'keys' => ['shared_secret']
      }
    }
  end

  describe '#initialize' do
    it 'stores the yaml hash data' do
      env = Lotus::Environment.new(yaml_hash)
      expect(env.data).to eq(yaml_hash)
    end
  end

  describe '.from_yaml' do
    it 'creates instance from yaml object' do
      env = Lotus::Environment.from_yaml(yaml_hash)
      expect(env).to be_a(Lotus::Environment)
      expect(env.data).to eq(yaml_hash)
    end
  end

  describe '#group' do
    it 'returns the group value' do
      env = Lotus::Environment.new(yaml_hash)
      expect(env.group).to eq('test-group')
    end

    it 'returns nil when group is missing' do
      env = Lotus::Environment.new({})
      expect(env.group).to be_nil
    end
  end

  describe '#configs' do
    it 'returns the configs hash' do
      env = Lotus::Environment.new(yaml_hash)
      expect(env.configs).to eq(yaml_hash['configs'])
    end

    it 'returns empty hash when configs is missing' do
      env = Lotus::Environment.new({})
      expect(env.configs).to eq({})
    end
  end

  describe '#secret_keys' do
    it 'returns array of secret keys' do
      env = Lotus::Environment.new(yaml_hash)
      expect(env.secret_keys).to eq(['secret_key', 'api_secret'])
    end

    it 'returns empty array when secrets is missing' do
      env = Lotus::Environment.new({})
      expect(env.secret_keys).to eq([])
    end

    it 'returns empty array when secrets.keys is missing' do
      env = Lotus::Environment.new({'secrets' => {}})
      expect(env.secret_keys).to eq([])
    end
  end

  describe '#group_secret_keys' do
    it 'returns array of group secret keys' do
      env = Lotus::Environment.new(yaml_hash)
      expect(env.group_secret_keys).to eq(['shared_secret'])
    end

    it 'returns empty array when group_secrets is missing' do
      env = Lotus::Environment.new({})
      expect(env.group_secret_keys).to eq([])
    end
  end

  describe '.from_args' do
    context 'with production environment' do
      it 'sets space to prod for prod environments' do
        env = Lotus::Environment.from_args(environment: 'prod')
        expect(env.data['space']).to eq('prod')
        expect(env.data['environment']).to eq('prod')
        expect(env.data['application']).to eq('greenhouse')
      end

      it 'sets space to prod for staging environments' do
        env = Lotus::Environment.from_args(environment: 'staging')
        expect(env.data['space']).to eq('prod')
      end
    end

    context 'with numbered environments' do
      it 'sets region to use1 for s1-s99' do
        env = Lotus::Environment.from_args(environment: 'prod-s5')
        expect(env.data['region']).to eq('use1')
      end

      it 'sets region to euc1 for s101-s199' do
        env = Lotus::Environment.from_args(environment: 'prod-s150')
        expect(env.data['region']).to eq('euc1')
      end

      it 'sets region to apse2 for s201-s299' do
        env = Lotus::Environment.from_args(environment: 'prod-s250')
        expect(env.data['region']).to eq('apse2')
      end

      it 'sets no region for numbers outside ranges' do
        env = Lotus::Environment.from_args(environment: 'prod-s300')
        expect(env.data['region']).to be_nil
      end
    end

    context 'with custom parameters' do
      it 'uses provided space and region over defaults' do
        env = Lotus::Environment.from_args(
          environment: 'prod-s5',
          space: 'custom-space',
          region: 'custom-region',
          application: 'custom-app'
        )
        
        expect(env.data['space']).to eq('custom-space')
        expect(env.data['region']).to eq('custom-region')
        expect(env.data['application']).to eq('custom-app')
      end
    end

    context 'with non-prod environments' do
      it 'uses environment name as space' do
        env = Lotus::Environment.from_args(environment: 'development')
        expect(env.data['space']).to eq('development')
        expect(env.data['region']).to be_nil
      end
    end
  end
end
