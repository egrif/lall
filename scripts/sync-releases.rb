#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

def run_command(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success?
    puts "Error running: #{cmd}"
    puts "STDERR: #{stderr}"
    exit 1
  end
  stdout.strip
end

def git_tags
  output = run_command('git tag -l | grep "^v" | sort -V')
  output.split("\n").map(&:strip).reject(&:empty?)
end

def current_version
  version_file = File.read('lib/lall/version.rb')
  match = version_file.match(/VERSION = '([^']+)'/)
  match ? match[1] : nil
end

def create_github_release(tag, title, body)
  gem_file = "lall-#{tag.sub('v', '')}.gem"

  # Build the gem if it doesn't exist
  unless File.exist?(gem_file)
    puts "Building gem for #{tag}..."
    run_command('gem build lall.gemspec')
  end

  puts "Creating GitHub release for #{tag}..."

  # Create release body
  release_body = <<~BODY
    #{body}

    ## Installation

    ### From GitHub Packages
    ```bash
    gem install lall --source "https://rubygems.pkg.github.com/egrif"
    ```

    ### From RubyGems.org (after manual publish)
    ```bash
    gem install lall
    ```

    ## Usage

    ```bash
    lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [OPTIONS]
    ```

    See [README.md](README.md) for complete documentation.
  BODY

  # Write body to temp file to avoid shell escaping issues
  body_file = "/tmp/release_body_#{tag}.md"
  File.write(body_file, release_body)

  # Create the release
  cmd = "gh release create '#{tag}' --title '#{title}' --notes-file '#{body_file}' --latest '#{gem_file}'"
  run_command(cmd)

  # Clean up
  FileUtils.rm_f(body_file)

  puts "✅ Created release #{tag}"
end

def get_commit_message(tag)
  output = run_command("git tag -n99 #{tag}")
  lines = output.split("\n")
  # Remove the first line which is just "tag_name    message"
  lines.shift
  lines.join("\n").strip
end

# Main execution
version = current_version
puts "Current version in code: #{version}"

if version.nil?
  puts '❌ Could not extract version from lib/lall/version.rb'
  exit 1
end

current_tag = "v#{version}"
tags = git_tags
puts "Available tags: #{tags.join(', ')}"

# Check if current version has a release
unless tags.include?(current_tag)
  puts "❌ No tag found for current version #{current_tag}"
  puts 'Please create and push the tag first:'
  puts "  git tag -a #{current_tag} -m 'Release #{current_tag}'"
  puts "  git push origin #{current_tag}"
  exit 1
end

# Check which releases exist on GitHub
existing_releases = []
begin
  output = run_command('gh release list --limit 100')
  existing_releases = output.split("\n").map { |line| line.split("\t").first.strip }
rescue StandardError => e
  puts "Warning: Could not fetch existing releases (#{e.message}). Will try to create all."
end

puts "Existing releases: #{existing_releases.join(', ')}" unless existing_releases.empty?

# Create missing releases
tags.each do |tag|
  next if existing_releases.include?(tag)

  puts "\n📦 Missing release for #{tag}"

  # Get commit message for the tag
  commit_message = get_commit_message(tag)
  title = "Release #{tag}"

  begin
    create_github_release(tag, title, commit_message)
  rescue StandardError => e
    puts "❌ Failed to create release for #{tag}: #{e.message}"
  end
end

puts "\n🎉 Release sync complete!"
