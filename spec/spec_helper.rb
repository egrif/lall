# frozen_string_literal: true

require 'rspec'
require 'yaml'
require_relative '../lib/lall/cli'
require_relative '../lib/lall/key_searcher'
require_relative '../lib/lall/table_formatter'
require_relative '../lib/lall/cli_options'
require_relative '../lib/lall/version'
require_relative '../lib/lotus/runner'
require_relative '../lib/lotus/environment'
require_relative '../lib/lotus/group'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end

# Test fixtures
module SpecHelpers
  def sample_yaml_data
    {
      'group' => 'test-group',
      'configs' => {
        'database_url' => 'postgres://localhost:5432/test',
        'api_token' => 'abc123',
        'timeout' => 30
      },
      'secrets' => {
        'keys' => %w[secret_key api_secret]
      },
      'group_secrets' => {
        'keys' => ['shared_secret']
      }
    }
  end

  def complex_yaml_data
    {
      'group' => 'complex-group',
      'configs' => {
        'database' => {
          'host' => 'db.example.com',
          'port' => 5432,
          'credentials' => {
            'username' => 'dbuser',
            'password_ref' => 'db_password'
          }
        },
        'services' => {
          'auth_service' => 'https://auth.example.com',
          'payment_service' => 'https://pay.example.com'
        }
      },
      'secrets' => {
        'keys' => %w[db_password jwt_secret encryption_key]
      }
    }
  end
end

RSpec.configure do |config|
  config.include SpecHelpers
end
