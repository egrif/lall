# frozen_string_literal: true

require_relative 'lib/lall/version'

Gem::Specification.new do |spec|
  spec.name          = 'lall'
  spec.version       = Lall::VERSION
  spec.authors       = ['Eric Griffith']
  spec.email         = ['your.email@example.com']

  spec.summary       = 'LOTUS environment comparison CLI using lotus.'
  spec.description   = 'A Ruby CLI tool for comparing LOTUS configuration values across multiple ' \
                       'environments, using the lotus command to fetch environment data.'
  spec.homepage      = 'https://github.com/egrif/lall'
  spec.license       = 'MIT'

  spec.metadata = {
    'homepage_uri' => 'https://github.com/egrif/lall',
    'source_code_uri' => 'https://github.com/egrif/lall',
    'changelog_uri' => 'https://github.com/egrif/lall/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/egrif/lall/issues',
    'documentation_uri' => 'https://github.com/egrif/lall/blob/main/README.md',
    'rubygems_mfa_required' => 'true'
  }

  spec.files         = Dir['lib/**/*.rb'] + ['README.md', 'bin/lall', 'config/settings.yml']
  spec.executables   = ['lall']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.1.0'

  spec.add_dependency 'base64', '~> 0.2'
  spec.add_dependency 'digest', '~> 3.1'
  spec.add_dependency 'fileutils', '~> 1.7'
  spec.add_dependency 'open3', '~> 0.2'
  spec.add_dependency 'openssl', '~> 3.0'
  spec.add_dependency 'optparse', '~> 0.6'
  spec.add_dependency 'redis', '~> 5.0'
  spec.add_dependency 'yaml', '~> 0.3'

  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
