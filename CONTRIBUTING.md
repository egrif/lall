# Contributing to lall

Thank you for your interest in contributing to lall! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Testing](#testing)
- [Code Style](#code-style)
- [Submitting Changes](#submitting-changes)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a code of conduct that fosters an inclusive and respectful community. By participating, you agree to:

- Be respectful and inclusive in all interactions
- Focus on constructive feedback and collaboration
- Help maintain a welcoming environment for all contributors
- Report any unacceptable behavior to the maintainers

## Getting Started

### Prerequisites

- Ruby 2.7 or higher
- Bundler gem manager
- Git version control
- Access to lotus CLI (for integration testing)

### Development Setup

1. **Fork and clone the repository:**

```bash
git clone https://github.com/your-username/lall.git
cd lall
```

2. **Install dependencies:**

```bash
bundle install
```

3. **Verify setup:**

```bash
# Run tests
bundle exec rake spec

# Try the CLI
bin/lall --help
```

4. **Set up pre-commit hooks (optional but recommended):**

```bash
# Add to .git/hooks/pre-commit
#!/bin/bash
bundle exec rake spec
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

## Contributing Guidelines

### Types of Contributions

We welcome several types of contributions:

- **Bug fixes**: Fix issues or unexpected behavior
- **Features**: Add new functionality or improve existing features
- **Documentation**: Improve or add documentation
- **Tests**: Add test coverage or improve existing tests
- **Performance**: Optimize performance or resource usage
- **Refactoring**: Improve code organization or clarity

### Before You Start

1. **Check existing issues**: Look for related issues or feature requests
2. **Create an issue**: For significant changes, create an issue to discuss the approach
3. **Small changes**: For bug fixes or minor improvements, feel free to submit directly

### Development Workflow

1. **Create a feature branch:**

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

2. **Make your changes:**
   - Write code following the style guide
   - Add or update tests as needed
   - Update documentation if required

3. **Test your changes:**

```bash
# Run unit tests
bundle exec rake spec

# Run integration tests
bundle exec rake integration

# Test CLI manually
bin/lall -s test_pattern -g staging
```

4. **Commit your changes:**

```bash
git add .
git commit -m "Add feature: description of changes"
```

5. **Push and create pull request:**

```bash
git push origin feature/your-feature-name
```

## Testing

### Test Structure

```
spec/
├── spec_helper.rb          # Test configuration and helpers
├── *_spec.rb              # Unit tests for each class
├── lotus/                 # Tests for lotus module
│   ├── environment_spec.rb
│   ├── group_spec.rb
│   └── runner_spec.rb
└── integration_spec.rb    # End-to-end tests
```

### Running Tests

```bash
# All tests
bundle exec rake test

# Unit tests only
bundle exec rake spec

# Integration tests only  
bundle exec rake integration

# Specific test file
bundle exec rspec spec/key_searcher_spec.rb

# With coverage
bundle exec rspec --require spec_helper
```

### Writing Tests

#### Unit Tests

For each new class or method, write comprehensive unit tests:

```ruby
RSpec.describe MyNewClass do
  describe '#my_method' do
    it 'handles normal case' do
      result = subject.my_method('input')
      expect(result).to eq('expected')
    end

    it 'handles edge case' do
      result = subject.my_method('')
      expect(result).to be_nil
    end

    it 'handles error conditions' do
      expect { subject.my_method(nil) }.to raise_error(ArgumentError)
    end
  end
end
```

#### Integration Tests

For CLI features, add integration tests:

```ruby
it 'processes new CLI option correctly' do
  stdout, stderr, status = Open3.capture3(
    lall_command, '-s', 'pattern', '--new-option', 'value'
  )
  
  expect(status.exitstatus).to eq(0)
  expect(stdout).to include('expected output')
end
```

### Test Coverage Goals

- **Unit tests**: Maintain >90% code coverage
- **Integration tests**: Cover all CLI option combinations
- **Error handling**: Test all error conditions and edge cases
- **Performance**: Include tests for parallel processing functionality

## Code Style

### Ruby Style Guide

Follow standard Ruby conventions:

- Use 2 spaces for indentation (no tabs)
- Keep lines under 100 characters when possible
- Use snake_case for variables and methods
- Use CamelCase for classes and modules
- Add frozen_string_literal comment to all files

### Class Design Principles

- **Single Responsibility Principle**: Each class should have one clear purpose
- **Dependency Injection**: Pass dependencies rather than creating them internally
- **Thread Safety**: Ensure shared resources are properly synchronized
- **Error Handling**: Handle external command failures gracefully

### Documentation Style

- Add YARD-style comments for public methods
- Include parameter types and return values
- Provide usage examples for complex methods

```ruby
# Searches YAML structure for matching keys
#
# @param obj [Hash, Array] YAML data to search
# @param search_str [String] Pattern to match (supports wildcards)
# @param path [Array] Current path in YAML structure  
# @param options [Hash] Search options
# @return [Array<Hash>] Array of matching results
def search(obj, search_str, path = [], **options)
  # implementation
end
```

### Commit Message Format

Use clear, descriptive commit messages:

```
Add wildcard support for secret key patterns

- Implement wildcard matching in KeySearcher.match_key?
- Add comprehensive tests for pattern matching
- Update documentation with wildcard examples

Fixes #123
```

Format:
- **Subject line**: Imperative mood, under 50 characters
- **Body**: Explain what and why, not how
- **Footer**: Reference issues, breaking changes

## Submitting Changes

### Pull Request Process

1. **Ensure tests pass**: All tests must pass before submitting
2. **Update documentation**: Include relevant documentation updates
3. **Add changelog entry**: Document user-visible changes
4. **Write clear PR description**: Explain the change and its motivation

### Pull Request Template

```markdown
## Description
Brief description of the change and its motivation.

## Changes Made
- List of specific changes
- New features or fixes
- Documentation updates

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] Changelog updated
```

### Review Process

1. **Automated checks**: Tests and style checks must pass
2. **Code review**: At least one maintainer review required
3. **Integration testing**: Manual testing of new features
4. **Documentation review**: Ensure docs are accurate and complete

## Architecture Guidelines

### Adding New Features

When adding new features, consider:

1. **Backward compatibility**: Don't break existing functionality
2. **Performance impact**: Consider effect on parallel processing
3. **Error handling**: Handle lotus command failures gracefully
4. **Configuration**: Use existing configuration patterns
5. **Testing**: Add both unit and integration tests

### Modifying Core Classes

For changes to core classes:

- **LallCLI**: Focus on argument parsing and workflow orchestration
- **KeySearcher**: Maintain pattern matching efficiency and thread safety
- **TableFormatter**: Preserve existing output formats while adding new ones
- **Lotus::Runner**: Ensure robust external command handling

### Adding External Dependencies

Before adding new dependencies:

1. **Justify the need**: Is the dependency necessary?
2. **Evaluate alternatives**: Can we use existing libraries?
3. **Consider size**: Keep the gem lightweight
4. **Check compatibility**: Ensure Ruby version compatibility
5. **Update gemspec**: Add appropriate version constraints

## Release Process

### Version Numbering

We follow semantic versioning (SemVer):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Automated Release (Recommended)

1. **Update version and changelog**:
   ```bash
   # Update lib/lall/version.rb
   # Update CHANGELOG.md with changes
   ```

2. **Create a release on GitHub**:
   - Go to [Releases](https://github.com/egrif/lall/releases)
   - Click "Create a new release"
   - Use tag format: `v1.2.3`
   - Add release notes from CHANGELOG.md

3. **Automated publishing**:
   - GitHub Action automatically runs tests
   - Builds and publishes gem to GitHub Packages
   - Optionally publishes to RubyGems.org (if configured)

### Manual Release

Use the release script for local preparation:

```bash
./scripts/release 1.2.3
```

This script will:
- Update the version number
- Run all tests
- Build the gem locally for validation
- Provide next steps for tagging and pushing

### Release Workflow

The release is handled by `.github/workflows/release.yml` which:

1. **Triggers on**:
   - New tags starting with `v`
   - Published releases
   - Manual workflow dispatch

2. **Process**:
   - Runs full test suite on multiple Ruby versions
   - Builds the gem with updated version
   - Publishes to GitHub Packages
   - Publishes to RubyGems.org (for releases only)
   - Creates GitHub release with assets

### Package Distribution

- **GitHub Packages**: All releases and tags
- **RubyGems.org**: Only official releases (requires `RUBYGEMS_API_KEY` secret)

### Release Checklist

1. **Update version**: Modify `lib/lall/version.rb`
2. **Update changelog**: Document all changes in `CHANGELOG.md`
3. **Run tests locally**: `bundle exec rake test`
4. **Build gem locally**: `gem build lall.gemspec`
5. **Commit changes**: `git commit -m "Bump version to x.y.z"`
6. **Create release**: Use GitHub UI or push tag
7. **Verify publication**: Check GitHub Packages and/or RubyGems.org

### Changelog Format

```markdown
## [1.2.0] - 2024-02-15

### Added
- New --pivot-extended option for advanced table formatting
- Support for nested wildcard patterns in key searches

### Changed  
- Improved performance of parallel secret fetching
- Updated CLI help text for clarity

### Fixed
- Fixed truncation bug with very short strings
- Resolved thread safety issue in result aggregation

### Deprecated
- Old --format option (use --pivot instead)
```

## Getting Help

### Communication Channels

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Pull Request Comments**: For code review and implementation details

### Documentation

- **README.md**: Basic usage and installation
- **docs/API.md**: Detailed API documentation
- **docs/EXAMPLES.md**: Usage examples and patterns
- **Code comments**: Inline documentation for complex logic

### Development Questions

When asking for help:

1. **Provide context**: What are you trying to achieve?
2. **Include details**: Ruby version, OS, error messages
3. **Show code**: Include relevant code snippets or test cases
4. **Describe attempts**: What have you already tried?

Thank you for contributing to lall! Your contributions help make this tool better for everyone.
