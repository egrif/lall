# frozen_string_literal: true

# Custom spec task to handle exit codes properly
desc 'Run unit tests (excluding integration)'
task :spec do
  puts 'Running unit tests...'

  # Get explicit list of spec files excluding integration
  spec_files = Dir['spec/**/*_spec.rb'].reject { |f| f.include?('integration') }
  spec_files_args = spec_files.join(' ')

  # Use backticks with explicit file list to avoid glob expansion issues
  output = `bundle exec rspec #{spec_files_args} 2>&1`

  puts output

  # Check if there were any failures in the output (more precise matching)
  if output.match(/(\d+) examples?, 0 failures/) && !output.include?('failed')
    puts 'All tests passed!'
    exit 0
  else
    puts 'Tests failed or had errors!'
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
