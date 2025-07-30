# Publishing and Distribution Guide

This document explains how the `lall` gem is built, packaged, and distributed using GitHub Actions.

## Overview

The `lall` gem is automatically built and published to GitHub Packages whenever:
- A new release is created on GitHub
- A tag starting with `v` is pushed (e.g., `v1.0.0`)
- The release workflow is manually triggered

## Workflows

### 1. Test Workflow (`.github/workflows/test.yml`)
- **Trigger**: Every push and pull request
- **Purpose**: Validate code quality and functionality
- **Actions**:
  - Run tests on Ruby 2.7, 3.0, 3.1, 3.2
  - Run RuboCop linting
  - Build gem for validation
  - Run security audit
  - Check spelling

### 2. Release Workflow (`.github/workflows/release.yml`)
- **Trigger**: Tags, releases, manual dispatch
- **Purpose**: Build and publish the gem
- **Jobs**:
  - **test**: Full test suite validation
  - **build**: Create gem package with version management
  - **publish-github**: Publish to GitHub Packages
  - **publish-rubygems**: Publish to RubyGems.org (optional)
  - **create-release**: Create GitHub release (manual trigger only)

## Release Process

### Automatic Release (Recommended)

1. **Prepare the release**:
   ```bash
   # Update version
   vim lib/lall/version.rb
   
   # Update changelog
   vim CHANGELOG.md
   
   # Commit changes
   git add -A
   git commit -m "Prepare v1.0.0 release"
   git push origin main
   ```

2. **Create release on GitHub**:
   - Go to [Releases](https://github.com/egrif/lall/releases/new)
   - Create tag: `v1.0.0`
   - Release title: `Release v1.0.0`
   - Add release notes from CHANGELOG.md
   - Click "Publish release"

3. **Automatic actions**:
   - GitHub Action runs tests
   - Builds gem with correct version
   - Publishes to GitHub Packages
   - Attaches gem file to release

### Manual Release

Use the helper script:

```bash
./scripts/release 1.0.0
```

This validates everything locally and provides next steps.

### Manual Workflow Trigger

For advanced users, trigger the workflow directly:

1. Go to Actions → Release Gem
2. Click "Run workflow"
3. Enter version number (e.g., `1.0.0`)
4. This will create a tag and release automatically

## Installation Methods

### From GitHub Packages

```bash
# One-time setup
gem sources --add https://rubygems.pkg.github.com/egrif

# Install
gem install lall --source "https://rubygems.pkg.github.com/egrif"
```

### From RubyGems.org (if configured)

```bash
gem install lall
```

### From Source

```bash
git clone https://github.com/egrif/lall.git
cd lall
bundle install
gem build lall.gemspec
gem install lall-*.gem
```

## Configuration Requirements

### GitHub Secrets

- `GITHUB_TOKEN`: Automatically provided, used for GitHub Packages
- `RUBYGEMS_API_KEY`: Optional, required for RubyGems.org publishing

### Permissions

The workflow requires:
- `contents: read` - To checkout code
- `packages: write` - To publish to GitHub Packages

## Package Information

- **Name**: `lall`
- **Registry**: GitHub Packages (`rubygems.pkg.github.com/egrif`)
- **Format**: Ruby Gem
- **Visibility**: Public (follows repository visibility)
- **Versioning**: Semantic versioning (SemVer)

## Troubleshooting

### Build Fails
- Check test results in the workflow logs
- Ensure all tests pass locally: `bundle exec rake test`
- Verify gemspec is valid: `gem build lall.gemspec`

### Publishing Fails
- Check GitHub token permissions
- Verify package registry is accessible
- Review workflow logs for specific errors

### Version Conflicts
- Ensure version in `lib/lall/version.rb` matches tag
- Check that version hasn't been published before
- Verify semantic versioning format (e.g., `1.0.0`)

### Installation Issues
- Verify gem source is configured correctly
- Check authentication for private packages
- Try installing with verbose output: `gem install -V lall`

## Monitoring

### Package Status
- View packages: [GitHub Packages](https://github.com/egrif/lall/packages)
- Check download stats on package page
- Monitor workflow runs in [Actions](https://github.com/egrif/lall/actions)

### Release Health
- Monitor test results across Ruby versions
- Check security audit results
- Review dependency updates from Dependabot

## Best Practices

1. **Always test before releasing**:
   ```bash
   bundle exec rake test
   gem build lall.gemspec
   ```

2. **Update documentation**:
   - CHANGELOG.md for user-facing changes
   - README.md for new features
   - Version numbers in all relevant files

3. **Use semantic versioning**:
   - MAJOR: Breaking changes
   - MINOR: New features (backward compatible)
   - PATCH: Bug fixes

4. **Validate locally first**:
   ```bash
   ./scripts/release 1.0.0  # Validates everything
   ```

5. **Create meaningful releases**:
   - Clear release notes
   - Reference fixed issues
   - Include upgrade instructions for breaking changes
