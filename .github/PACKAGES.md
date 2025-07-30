# GitHub Packages Configuration for lall gem

## Publishing to GitHub Packages

This repository is configured to automatically publish the `lall` gem to GitHub Packages when:

1. A new release is created
2. A tag starting with `v` is pushed
3. The release workflow is manually triggered

## Installation from GitHub Packages

To install the gem from GitHub Packages, you need to configure your environment:

### 1. Configure Bundler (recommended)

Add to your `Gemfile`:

```ruby
source "https://rubygems.pkg.github.com/egrif" do
  gem "lall"
end
```

### 2. Configure gem command

Create or update `~/.gemrc`:

```yaml
---
:sources:
  - https://rubygems.org/
  - https://rubygems.pkg.github.com/egrif
```

### 3. Authentication

For private repositories, create a personal access token with `read:packages` permission and configure:

```bash
# For Bundler (replace USERNAME and TOKEN with your actual values)
bundle config https://rubygems.pkg.github.com/egrif <USERNAME>:<PERSONAL_ACCESS_TOKEN>

# For gem command (replace USERNAME and TOKEN with your actual values)
gem sources --add https://<USERNAME>:<PERSONAL_ACCESS_TOKEN>@rubygems.pkg.github.com/egrif
```

**Note**: Replace `<USERNAME>` with your GitHub username and `<PERSONAL_ACCESS_TOKEN>` with a personal access token that has `read:packages` permission.

### 4. Install the gem

```bash
gem install lall --source "https://rubygems.pkg.github.com/egrif"
```

## Package Information

- **Package Registry**: GitHub Packages
- **Package Type**: RubyGem
- **Visibility**: Public (follows repository visibility)
- **Namespace**: `@egrif/lall`

## Release Process

### Automatic Release (Recommended)

1. Update `CHANGELOG.md` with your changes
2. Create a new release on GitHub with a tag like `v1.0.0`
3. The workflow will automatically:
   - Run all tests
   - Build the gem
   - Publish to GitHub Packages
   - Publish to RubyGems.org (if configured)

### Manual Release

1. Go to Actions → Release Gem → Run workflow
2. Enter the version number (e.g., `1.0.0`)
3. The workflow will create a tag and release

## Required Secrets

For full functionality, configure these repository secrets:

- `GITHUB_TOKEN` - Automatically provided by GitHub
- `RUBYGEMS_API_KEY` - Optional, for publishing to RubyGems.org

## Workflow Files

- `.github/workflows/release.yml` - Gem building and publishing
- `.github/workflows/test.yml` - Testing and validation
