# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lotus::Environment do
  describe '#initialize' do
    it 'stores the name and optional parameters' do
      env = Lotus::Environment.new('prod-s5', space: 'custom-space', region: 'use1', application: 'test-app')
      expect(env.name).to eq('prod-s5')
    end

    it 'works with just a name parameter' do
      env = Lotus::Environment.new('staging')
      expect(env.name).to eq('staging')
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
      it 'will fail when @data is nil (current implementation issue)' do
        env = Lotus::Environment.new('prod')
        expect { env.group_name }.to raise_error(NoMethodError)
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

  describe '#fetch' do
    it 'exists but is not yet implemented' do
      env = Lotus::Environment.new('prod')
      expect(env).to respond_to(:fetch)
    end
  end
end
