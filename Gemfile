# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in lall.gemspec
gemspec

group :development, :test do
  gem 'pry', '~> 0.14'

  # pry-byebug requires different versions based on Ruby version
  if RUBY_VERSION >= '3.1'
    gem 'pry-byebug', '~> 3.10'
  elsif RUBY_VERSION >= '3.0'
    gem 'pry-byebug', '~> 3.9.0'
  else
    # For Ruby 2.7, use an older compatible version
    gem 'pry-byebug', '~> 3.8.0'
  end

  # Use compatible RuboCop versions
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
