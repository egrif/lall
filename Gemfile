# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in lall.gemspec
gemspec

group :development, :test do
  gem 'pry', '~> 0.14'
  gem 'pry-byebug', '~> 3.10'

  # Use compatible versions for Ruby 2.7
  if RUBY_VERSION >= '3.0'
    gem 'rubocop', '~> 1.50', require: false
    gem 'rubocop-rspec', '~> 2.20', require: false
  else
    gem 'rubocop', '~> 1.48', require: false
    gem 'rubocop-rspec', '~> 2.18', require: false
  end

  gem 'simplecov', '~> 0.22', require: false
end

gem 'csv'
gem 'redis', '~> 5.4'
