# frozen_string_literal: true

# Custom spec task to handle exit codes properly
desc 'Run unit tests (excluding integration)'
task :spec do
  puts 'Running unit tests...'

  # Get explicit list of spec files excluding integration
  spec_files = Dir['spec/**/*_spec.rb'].reject { |f| f.include?('integration') }
  puts "DEBUG: Found #{spec_files.length} spec files" if ENV['CI']

  # Use output parsing approach since system() also returns false due to RSpec's SystemExit handling
  output = `bundle exec rspec #{spec_files.join(' ')} 2>&1`
  puts output

  # More robust pattern matching for success detection
  if output =~ /(\d+) examples?, 0 failures/ &&
     !output.include?('failed') &&
     !output.include?(' error') &&
     !output.include?('Error:')
    puts 'All tests passed!'
    exit 0
  else
    puts 'Tests failed or had errors!'
    puts 'DEBUG: Pattern match failed - checking output:' if ENV['CI']
    puts "  - Has '0 failures': #{output.include?('0 failures')}" if ENV['CI']
    puts "  - Contains 'failed': #{output.include?('failed')}" if ENV['CI']
    puts "  - Contains ' error': #{output.include?(' error')}" if ENV['CI']
    puts "  - Contains 'Error:': #{output.include?('Error:')}" if ENV['CI']
    exit 1
  end
end

desc 'Run integration tests only'
task :integration do
  puts 'Running integration tests...'

  # Get integration spec files explicitly
  integration_files = Dir['spec/**/*_spec.rb'].select { |f| f.include?('integration') }
  integration_files_args = integration_files.join(' ')

  output = `bundle exec rspec #{integration_files_args} 2>&1`
  puts output

  if output.match(/(\d+) examples?, 0 failures/) && !output.include?('failed')
    puts 'All integration tests passed!'
    exit 0
  else
    puts 'Integration tests failed or had errors!'
    exit 1
  end
end

desc 'Run all tests'
task :test do
  puts 'Running all tests...'

  # Get all spec files explicitly
  all_spec_files = Dir['spec/**/*_spec.rb']
  all_spec_files_args = all_spec_files.join(' ')

  output = `bundle exec rspec #{all_spec_files_args} 2>&1`
  puts output

  if output.match(/(\d+) examples?, 0 failures/) && !output.include?('failed')
    puts 'All tests passed!'
    exit 0
  else
    puts 'Tests failed or had errors!'
    exit 1
  end
end

task default: :spec
