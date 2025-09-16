# frozen_string_literal: true

# Custom spec task to handle exit codes properly
desc 'Run unit tests (excluding integration)'
task :spec do
  puts 'Running unit tests...'

  # Use shell glob expansion and exclude integration file specifically
  output = `bundle exec rspec spec/**/*_spec.rb --exclude-pattern spec/integration_spec.rb 2>&1`

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

  output = `bundle exec rspec spec/integration_spec.rb 2>&1`
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

  output = `bundle exec rspec spec/**/*_spec.rb 2>&1`
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
