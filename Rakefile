# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |task|
  task.exclude_pattern = 'spec/**/*integration*'
end

RSpec::Core::RakeTask.new(:integration) do |task|
  task.pattern = 'spec/**/*integration*'
end

desc 'Run all tests'
task test: %i[spec integration]

desc 'Run unit tests only'
task unit: :spec

desc 'Run integration tests only'
task integration_tests: :integration

task default: :spec
