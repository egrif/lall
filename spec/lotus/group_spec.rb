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

  describe '#initialize' do
    it 'stores the yaml hash data' do
      group = Lotus::Group.new(yaml_hash)
      expect(group.data).to eq(yaml_hash)
    end
  end

  describe '#configs' do
    it 'returns the configs hash' do
      group = Lotus::Group.new(yaml_hash)
      expect(group.configs).to eq(yaml_hash['configs'])
    end

    it 'returns empty hash when configs is missing' do
      group = Lotus::Group.new({})
      expect(group.configs).to eq({})
    end
  end

  describe '#secrets' do
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
end
