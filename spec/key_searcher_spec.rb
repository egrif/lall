# frozen_string_literal: true

require 'spec_helper'

RSpec.describe KeySearcher do
  describe '.match_key?' do
    context 'with exact matches' do
      it 'matches exact strings' do
        expect(KeySearcher.match_key?('database_url', 'database_url')).to be true
        expect(KeySearcher.match_key?('api_token', 'database_url')).to be false
      end
    end

    context 'with wildcard matches' do
      it 'matches with single wildcard' do
        expect(KeySearcher.match_key?('database_url', 'database_*')).to be true
        expect(KeySearcher.match_key?('api_token', 'api_*')).to be true
        expect(KeySearcher.match_key?('timeout', 'api_*')).to be false
      end

      it 'matches with wildcard at beginning' do
        expect(KeySearcher.match_key?('database_url', '*_url')).to be true
        expect(KeySearcher.match_key?('api_url', '*_url')).to be true
        expect(KeySearcher.match_key?('timeout', '*_url')).to be false
      end

      it 'matches with wildcard in middle' do
        expect(KeySearcher.match_key?('database_connection_url', 'database_*_url')).to be true
        expect(KeySearcher.match_key?('database_url', 'database_*_url')).to be false
      end

      it 'matches with multiple wildcards' do
        expect(KeySearcher.match_key?('my_database_connection_url', '*_database_*_url')).to be true
        expect(KeySearcher.match_key?('database_url', '*_*')).to be true
      end
    end
  end

  describe '.handle_secret_match' do
    let(:results) { [] }
    let(:secret_jobs) { [] }

    context 'when expose is false' do
      it 'adds result without creating secret job' do
        KeySearcher.handle_secret_match(
          results, secret_jobs, ['configs'], 'api_token', 'value123', false, 'test-env'
        )

        expect(results).to eq([{ path: 'configs.api_token', key: 'api_token', value: 'value123', color: nil }])
        expect(secret_jobs).to be_empty
      end
    end

    context 'when expose is true and path includes secrets' do
      it 'creates secret job and adds pending result' do
        KeySearcher.handle_secret_match(
          results, secret_jobs, ['secrets'], 'secret_key', 'value123', true, 'test-env'
        )

        expect(results).to eq([{ path: 'secrets.secret_key', key: 'secret_key', value: :__PENDING_SECRET__, color: nil }])
        expect(secret_jobs).to eq([{ env: 'test-env', key: 'secret_key', path: 'secrets.secret_key', k: 'secret_key', color: nil }])
      end
    end

    context 'when expose is true and path includes group_secrets' do
      it 'creates secret job for group secrets' do
        KeySearcher.handle_secret_match(
          results, secret_jobs, ['group_secrets'], 'shared_secret', 'value123', true, 'test-env'
        )

        expect(results).to eq([{ path: 'group_secrets.shared_secret', key: 'shared_secret', value: :__PENDING_SECRET__, color: nil }])
        expect(secret_jobs).to eq([{ env: 'test-env', key: 'shared_secret', path: 'group_secrets.shared_secret', k: 'shared_secret', color: nil }])
      end
    end

    context 'with array index' do
      it 'includes index in path' do
        KeySearcher.handle_secret_match(
          results, secret_jobs, %w[secrets keys], 'secret_key', '{SECRET}', false, 'test-env', idx: 0
        )

        expect(results).to eq([{ path: 'secrets.keys.0', key: 'secret_key', value: '{SECRET}', color: nil }])
      end
    end
  end

  describe '.find_group' do
    it 'returns group from hash' do
      obj = { 'group' => 'test-group', 'configs' => {} }
      expect(KeySearcher.find_group(obj)).to eq('test-group')
    end

    it 'returns nil for non-hash objects' do
      expect(KeySearcher.find_group('string')).to be_nil
      expect(KeySearcher.find_group([])).to be_nil
    end

    it 'returns nil when group key is missing' do
      obj = { 'configs' => {} }
      expect(KeySearcher.find_group(obj)).to be_nil
    end
  end

  describe '.search' do
    let(:yaml_data) { sample_yaml_data }

    context 'searching in hash structures' do
      it 'finds exact key matches' do
        results = KeySearcher.search(yaml_data, 'api_token')

        expect(results.length).to eq(1)
        expect(results.first[:key]).to eq('api_token')
        expect(results.first[:value]).to eq('abc123')
        expect(results.first[:path]).to eq('configs.api_token')
      end

      it 'finds wildcard matches' do
        results = KeySearcher.search(yaml_data, 'api_*')

        expect(results.length).to eq(2)
        keys = results.map { |r| r[:key] }
        expect(keys).to include('api_token', 'api_secret')
      end

      it 'finds multiple matches with wildcards' do
        results = KeySearcher.search(yaml_data, '*_*')

        expect(results.length).to be >= 2
        keys = results.map { |r| r[:key] }
        expect(keys).to include('database_url', 'api_token')
      end
    end

    context 'searching in array structures' do
      it 'finds matches in secret key arrays' do
        results = KeySearcher.search(yaml_data, 'secret_key')

        secret_results = results.select { |r| r[:path].include?('secrets') }
        expect(secret_results).not_to be_empty
      end

      it 'finds wildcard matches in arrays' do
        results = KeySearcher.search(yaml_data, '*_secret')

        expect(results.map { |r| r[:key] }).to include('api_secret', 'shared_secret')
      end
    end

    context 'with expose option' do
      before do
        allow(Lotus::Runner).to receive(:secret_get).and_return('SECRET_KEY=actual_secret_value')
      end

      it 'fetches actual secret values when expose is true' do
        results = KeySearcher.search(yaml_data, 'secret_key', env: 'test-env', expose: true)

        secret_result = results.find { |r| r[:key] == 'secret_key' && r[:path].include?('secrets') }
        expect(secret_result[:value]).to eq('actual_secret_value')
      end

      it 'does not fetch secrets when expose is false' do
        results = KeySearcher.search(yaml_data, 'secret_key', env: 'test-env', expose: false)

        secret_result = results.find { |r| r[:key] == 'secret_key' && r[:path].include?('secrets') }
        expect(secret_result[:value]).to eq('{SECRET}')
      end
    end

    context 'with complex nested structures' do
      let(:complex_data) { complex_yaml_data }

      it 'finds deeply nested matches' do
        results = KeySearcher.search(complex_data, 'username')

        expect(results.length).to eq(1)
        expect(results.first[:path]).to eq('configs.database.credentials.username')
        expect(results.first[:value]).to eq('dbuser')
      end

      it 'finds service URLs with wildcards' do
        results = KeySearcher.search(complex_data, '*_service')

        expect(results.length).to eq(2)
        services = results.map { |r| r[:key] }
        expect(services).to include('auth_service', 'payment_service')
      end
    end

    context 'case sensitivity' do
      it 'performs case-sensitive search by default' do
        results = KeySearcher.search(yaml_data, 'API_TOKEN')

        expect(results).to be_empty
      end

      # NOTE: The current implementation now properly supports case-insensitive search
      # This test verifies the expected behavior
      it 'performs case-insensitive search when insensitive is true' do
        results = KeySearcher.search(yaml_data, 'API_TOKEN', [], [], insensitive: true, search_data: yaml_data)

        # Should find the api_token match when searching case-insensitively
        expect(results).to eq([{ path: 'configs.api_token', key: 'api_token', value: 'abc123', color: :white }])
      end
    end
  end
end
