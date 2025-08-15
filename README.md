# lall

A Ruby CLI tool for comparing YAML configuration values across multiple environments, using the `lotus` command to fetch environment data.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%202.7-ruby.svg)](https://ruby-lang.org)
[![Tests](https://img.shields.io/badge/tests-passing-green.svg)](https://github.com/egrif/lall)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic Usage](#basic-usage)
  - [Command Line Options](#command-line-options)
  - [Environment Groups](#environment-groups)
  - [Output Formats](#output-formats)
  - [Secret Management](#secret-management)
- [Examples](#examples)
- [Caching](#caching)
- [Configuration](#configuration)
- [Development](#development)
- [Testing](#testing)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Multi-environment comparison**: Compare configuration values across multiple environments simultaneously
- **Flexible search patterns**: Support for exact matches and wildcard patterns (`*`) in key searches
- **Multiple output formats**: 
  - Standard key-based table
  - Path-included table (with `-p` flag)
  - Pivoted table (with `-v` flag, environments as rows)
- **Environment groups**: Pre-configured groups of environments for quick multi-env queries
- **Secret management**: Optionally expose actual secret values with the `-x/--expose` flag
- **Performance optimized**: Threaded parallel fetching of environment data and secrets
- **Thread-safe architecture** *(v0.7.0+)*: 
  - Singleton pattern for core managers (CacheManager, SettingsManager)
  - Thread-safe operations with mutex protection
  - Enhanced EntitySet with dual initialization modes
  - Cache-first Environment data loading with intelligent fallback
- **Advanced caching system**: 
  - Redis backend (if `REDIS_URL` available) with Moneta file fallback
  - Encrypted secret storage using AES-256-GCM
  - Configurable TTL, cache directories, and prefixes
  - Cache namespace isolation for multi-application environments
  - Selective cache clearing with prefix-aware operations
  - Cache management commands (`--cache-stats`, `--clear-cache`, etc.)
- **Customizable output**: Truncation control, case-insensitive search options, semantic color coding
- **Debug support**: Built-in debugging capabilities with detailed command output
- **Modular architecture**: Clean, maintainable code following Single Responsibility Principle

## Installation

### Prerequisites

- Ruby 3.1 or higher
- The `lotus` command must be available in your PATH
- Access to the target environments through the lotus CLI
- Optional: Redis server for enhanced caching performance

### Install from GitHub Packages

```bash
# make sure the repo is accessible.  
# Give at least read_packages scope to the token (Settings | Developer Settings | Personal Access Tokens | Tokens (classic)
bundle config set --global https://rubygems.pkg.github.com/egrif GITHUB_USERNAME:TOKEN

# If the `gem install` command below doesn't find the gem, then Configure gem source
gem sources --add https://GITHUB_USERNAME:TOKEN@rubygems.pkg.github.com/egrif

# Install the gem
gem install lall # if necessary: --source "https://rubygems.pkg.github.com/egrif"
```

```bash
git clone https://github.com/egrif/lall.git
cd lall
bundle install
gem build lall.gemspec
gem install lall-<VERSION>.gem
```

### Development installation

```bash
git clone https://github.com/egrif/lall.git
cd lall
bundle install
# Use bin/lall directly or create symlink
ln -s $(pwd)/bin/lall /usr/local/bin/lall
```

## Usage

### Basic Usage

```bash
lall -m MATCH [-e ENV[,ENV2,...]] [-g GROUP] [OPTIONS]
```

**Required arguments:**
- `-m, --match=MATCH` : Glob pattern to search for in YAML keys (required)
- Either `-e, --env=ENV` OR `-g, --group=GROUP` (mutually exclusive)

### Command Line Options

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-m` | `--match=MATCH` | Glob pattern to search for in YAML keys (required) | |
| `-e` | `--env=ENV` | Comma-separated environment(s) to search. Format: `name[:space[:region]]` | |
| `-g` | `--group=GROUP` | Predefined group of environments | |
| `-s` | `--space=SPACE` | Default space for environments if not specified in `-e` | `prod` |
| `-a` | `--application=APP` | Default application for environments | `greenhouse` |
| `-r` | `--region=REGION` | Default region for environments if not specified in `-e` | |
| `-p` | `--path` | Include the full path column in output | `false` |
| `-i` | `--insensitive` | Case-insensitive key search | `false` |
| `-v` | `--pivot` | Pivot table (environments as rows, keys as columns) | `false` |
| `-t[LEN]` | `--truncate[=LEN]` | Truncate values longer than LEN characters | `40` |
| `-x` | `--expose` | Expose actual secret values (fetches from lotus) | `false` |
| `-d` | `--debug` | Enable debug output (shows lotus commands) | `false` |
| | `--cache-ttl=SECONDS` | Set cache TTL in seconds | `3600` |
| | `--cache-dir=PATH` | Set cache directory path | `~/.lall/cache` |
| | `--cache-prefix=PREFIX` | Set cache key prefix for isolation | `lall-cache` |
| | `--no-cache` | Disable caching for this request | `false` |
| | `--clear-cache` | Clear cache entries with matching prefix and exit | |
| | `--cache-stats` | Show cache statistics (size, backend, entity counts) and exit | |
| | `--debug-settings` | Show settings resolution and exit | |
| | `--show-settings` | Show all resolved settings and exit | |
| | `--init-settings` | Initialize user settings file and exit | |

### Environment Groups

Environment groups are defined in `config/settings.yml` and allow you to query multiple related environments with a single command:

```yaml
groups:
  staging:
    - staging
    - staging-s2
    - staging-s3
  prod-us:
    - prod
    - prod-s2
    - prod-s3
    - prod-s4
  prod-all:
    - prod
    - prod-s101  # EU region
    - prod-s201  # APAC region
```

### Output Formats

#### Color Coding System

Lall uses semantic colors to indicate the source and relationship of configuration values:

- **White**: Environment-only value (no corresponding group value)
- **Blue**: Group value with no environment override 
- **Yellow**: Environment overrides group value (values differ)
- **Green**: Environment matches group value (values are the same)

This color coding helps quickly identify configuration differences and inheritance patterns across environments and groups.

#### Standard Key Table (default)
```bash
lall -s api_token -e prod,staging
```
```
| Key       | prod      | staging   |
|-----------|-----------|-----------|
| api_token | token123  | token456  |
```

#### With Path Information (`-p`)
```bash
lall -s api_token -e prod,staging -p
```
```
| Path              | Key       | prod      | staging   |
|-------------------|-----------|-----------|-----------|
| configs.api_token | api_token | token123  | token456  |
```

#### Pivoted Table (`-v`)
```bash
lall -s api_token -e prod,staging -v
```
```
| Env     | api_token |
|---------|-----------|
| prod    | token123  |
| staging | token456  |
```

### Secret Management

The tool can handle two types of secrets:

1. **Regular secrets** (`secrets.keys`): Environment-specific secrets
2. **Group secrets** (`group_secrets.keys`): Shared across environments in the same group

By default, secret keys show `{SECRET}` as values. Use `-x/--expose` to fetch actual values:

```bash
# Show secret keys without values
lall -s secret_key -g prod-us

# Expose actual secret values  
lall -s secret_key -g prod-us -x
```

## Examples

### Basic Searches

```bash
# Find all API tokens across production environments
lall -s api_token -g prod-us

# Search for database configuration in specific environments
lall -s database_* -e prod,staging,development

# Case-insensitive search for timeout settings
lall -s timeout -g staging -i

# Find all keys containing "service" 
lall -s *service* -e prod -p
```

### Advanced Usage

```bash
# Comprehensive production audit with secrets exposed
lall -s '*' -g prod-all -p -v -t100 -x

# Debug lotus commands being executed
lall -s api_* -e prod -d

# Compact view with short truncation
lall -s database_url -g prod-us -t20

# Full path view of configuration structure
lall -s config* -e prod -p -v
```

### Caching Examples

```bash
# Enable caching with custom TTL (2 hours)
lall -s database_* -e prod --cache-ttl=7200

# Use custom cache directory for isolation
lall -s secrets_* -e prod --cache-dir=/secure/cache

# Use cache prefix for multi-application environments
lall -s config_* -e prod --cache-prefix=web-app

# Disable caching for real-time sensitive data
lall -s current_timestamp -e prod --no-cache

# View cache statistics (shows size, backend info, and entity counts)
lall --cache-stats

# Clear cache entries with specific prefix
lall --cache-prefix=web-app --clear-cache

# Clear all cache and perform fresh scan
lall --clear-cache && lall -s '*' -g prod-all
```

### Settings Examples

```bash
# Initialize your personal settings file
lall --init-settings

# View how settings are resolved
lall --debug-settings

# Show all current settings in a comprehensive view
lall --show-settings

# Use environment variable defaults
export LALL_CACHE_TTL=7200
export LALL_DEBUG=true
lall -s database_* -e prod
```

### Wildcard Patterns

```bash
# Beginning wildcard: find all keys ending with "_url"
lall -s *_url -e prod

# End wildcard: find all keys starting with "api_"  
lall -s api_* -e prod

# Middle wildcard: find keys with pattern "database_*_timeout"
lall -s database_*_timeout -e prod

# Multiple wildcards: complex pattern matching
lall -s *_database_*_config -e prod
```

## Caching

Lall includes an advanced caching system to improve performance when searching across multiple environments. The cache stores search results temporarily, reducing the need to re-query configuration sources.

### Cache Backends

- **Redis (Primary)**: Fast in-memory caching with support for TTL and pattern-based operations
- **Moneta File (Fallback)**: Reliable file-based caching when Redis is unavailable

### Cache Isolation

Cache entries are isolated using configurable prefixes, allowing multiple applications or environments to share cache storage without conflicts:

- **Default prefix**: `lall-cache`
- **Configurable**: Set via `--cache-prefix`, environment variable, or settings file
- **Selective clearing**: Only entries with matching prefix are cleared

### Security

All cached data is encrypted using AES-256-GCM encryption. A unique encryption key is generated per session and stored securely.

### Cache Configuration

```bash
# Set custom cache TTL (default: 1 hour)
lall -s database -e prod --cache-ttl=7200

# Use custom cache directory
lall -s database -e prod --cache-dir=/tmp/my-cache

# Use custom cache prefix for isolation
lall -s database -e prod --cache-prefix=my-app

# Disable caching for sensitive operations
lall -s secrets -e prod --no-cache

# Clear cache entries with specific prefix
lall --cache-prefix=my-app --clear-cache

# View cache statistics (shows size, backend info, and entity counts)
lall --cache-stats
```

### Cache Management

- Cache entries automatically expire based on TTL
- Cache keys are prefixed for namespace isolation (default: `lall-cache`)
- Cache clearing operations respect prefix boundaries
- Failed cache operations gracefully fallback to direct queries

## Configuration

### Settings Priority Resolution

Lall follows a clear priority order for configuration settings:

1. **Command line arguments** (highest priority)
2. **Environment variables**
3. **User settings file** (`~/.lall/settings.yml`)
4. **Gem default settings** (`config/settings.yml`, lowest priority)

#### Environment Variables

Set these environment variables to configure default behavior:

```bash
export LALL_CACHE_TTL=7200          # Cache TTL in seconds
export LALL_CACHE_DIR=/my/cache     # Cache directory path
export LALL_CACHE_PREFIX=my-app     # Cache key prefix for isolation
export LALL_CACHE_ENABLED=false     # Enable/disable caching
export LALL_DEBUG=true              # Enable debug output
export LALL_TRUNCATE=60             # Default truncation length
export REDIS_URL=redis://localhost  # Redis connection URL
```

#### User Settings File

Create `~/.lall/settings.yml` to customize your personal defaults:

```bash
# Initialize a settings file with defaults and comments
lall --init-settings
```

This creates a well-commented settings file you can customize:

```yaml
cache:
  ttl: 7200                    # 2 hours instead of default 1 hour
  directory: ~/my-lall-cache   # Custom cache location
  prefix: my-app               # Custom cache prefix for isolation
  enabled: true                # Enable caching by default

output:
  debug: false                 # Disable debug by default
  truncate: 60                 # Longer truncation
  colors:
    # Customize color scheme for value display
    from_env: white            # Environment-only values
    from_group: cyan           # Group values (changed from default blue)
    env_changes_group: yellow  # Environment overrides group
    env_mirrors_group: green   # Environment matches group
```

#### Debug Settings Resolution

Use `--debug-settings` to see how settings are resolved:

```bash
lall --debug-settings
```

This shows the current values and where they came from.

Use `--show-settings` to see all resolved settings in a comprehensive view:

```bash
lall --show-settings
```

This displays:
- All search, output, and color options with their current values
- Cache configuration and status
- Available environment groups
- Settings resolution priority information

### Environment Groups

Edit `config/settings.yml` to define custom environment groups and color settings:

```yaml
groups:
  # Development environments
  dev:
    - development
    - dev-feature-branch
    - local
  
  # Testing environments  
  test:
    - test
    - integration
    - qa
    
  # Production regions
  prod-us-east:
    - prod-s1
    - prod-s2
    - prod-s3
  
  prod-eu:
    - prod-s101
    - prod-s102
    
  # All production
  prod-global:
    - prod
    - prod-s1
    - prod-s2
    - prod-s101
    - prod-s201

# Output formatting with color configuration
output:
  colors:
    # Environment-only value (no group value present)
    from_env: white
    # Group value with no environment override
    from_group: blue
    # Environment overrides group value (different from group)
    env_changes_group: yellow
    # Environment matches group value (same as group)
    env_mirrors_group: green
```

### Lotus Integration

The tool automatically determines lotus command arguments based on environment names:

- **Space argument (`-s`)**: 
  - `prod` for environments starting with "prod" or "staging"
  - Environment name for others
  
- **Region argument (`-r`)**:
  - `use1` for environments ending with s1-s99
  - `euc1` for environments ending with s101-s199  
  - `apse2` for environments ending with s201-s299

## Development

### Project Structure

```
lall/
├── bin/
│   └── lall                    # Executable CLI entry point
├── config/
│   └── settings.yml           # Environment group definitions
├── lib/
│   ├── lall/
│   │   ├── cli.rb             # Main CLI class and argument parsing
│   │   ├── cli_options.rb     # Options handling with defaults
│   │   ├── key_searcher.rb    # YAML traversal and key matching
│   │   ├── table_formatter.rb # Output formatting and display
│   │   └── version.rb         # Gem version
│   └── lotus/
│       ├── environment.rb     # Environment data modeling
│       ├── group.rb          # Group data modeling  
│       └── runner.rb         # Lotus command execution
├── spec/                      # RSpec test suite
├── test/
│   └── fixtures/             # Test data and configurations
└── Rakefile                  # Build and test tasks
```

### Setting Up Development Environment

```bash
# Clone and setup
git clone https://github.com/egrif/lall.git
cd lall
bundle install

# Run tests
bundle exec rake test           # All tests
bundle exec rake spec          # Unit tests only  
bundle exec rake integration   # Integration tests only

# Development console
bundle exec pry -r ./lib/lall/cli

# Build gem
gem build lall.gemspec
```

### Code Style and Architecture

The codebase follows these principles:

- **Single Responsibility Principle**: Each class has one clear purpose
- **Modular Design**: Clear separation between CLI, search, formatting, and external API concerns
- **Thread Safety**: Parallel processing with proper synchronization
- **Error Handling**: Graceful handling of external command failures
- **Testability**: High test coverage with unit and integration tests

#### Key Classes

- **`LallCLI`**: Main entry point, argument parsing, workflow orchestration, and entity-based search
- **`TableFormatter`**: Output formatting in multiple styles with configurable color system
- **`Lotus::Runner`**: External lotus command execution and response parsing
- **`Lotus::Environment`**: Environment data modeling and region logic
- **`Lotus::EntitySet`**: Entity management with dual initialization modes
- **`SettingsManager`**: Thread-safe singleton for configuration management
- **`CacheManager`**: Thread-safe singleton for cache operations with Redis/Moneta backends

## Testing

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Unit tests only (fast)
bundle exec rake spec

# Integration tests (requires lotus or mocks)
bundle exec rake integration

# With coverage report
bundle exec rspec --require spec_helper

# Specific test files
bundle exec rspec spec/key_searcher_spec.rb
bundle exec rspec spec/lotus/runner_spec.rb
```

### Test Structure

- **Unit Tests** (`spec/*_spec.rb`): Test individual classes and methods
- **Integration Tests** (`spec/integration_spec.rb`): End-to-end workflow testing
- **Fixtures** (`test/fixtures/`): Sample YAML data and configurations
- **Mocking**: External lotus commands are mocked for reliable testing

### Test Coverage

The test suite covers:

- ✅ All CLI argument parsing and validation
- ✅ Entity-based search and pattern matching algorithms  
- ✅ All output formatting options with color system
- ✅ Secret fetching and parallel processing
- ✅ Lotus command construction and parsing
- ✅ Thread-safe singleton managers (Settings, Cache)
- ✅ Error handling and edge cases
- ✅ Environment group configuration
- ✅ Integration workflows

## Architecture

### Data Flow

```
1. CLI Argument Parsing (LallCLI)
     ↓
2. Settings Resolution (SettingsManager with priority hierarchy)
     ↓
3. Environment Resolution (groups → EntitySet creation)  
     ↓
4. Lotus Ping (connectivity check)
     ↓  
5. Parallel Environment Fetching (Lotus::Runner.fetch_env_yaml)
     ↓
6. Entity-based Search & Secret Resolution (CLI direct search)
     ↓
7. Color Assignment & Result Aggregation (TableFormatter with color system)
     ↓
8. Output Display with Semantic Colors
```

### Threading Model

- **Environment fetching**: Parallel threads for each environment's YAML data
- **Secret fetching**: Parallel threads for each secret key lookup
- **Thread safety**: Mutex synchronization for result aggregation
- **Error isolation**: Individual thread failures don't crash the entire operation

### External Dependencies

- **Lotus CLI**: Must be installed and configured for target environments
- **YAML parsing**: Uses Ruby's built-in YAML library
- **Threading**: Ruby's built-in Thread class with Mutex for synchronization
- **Command execution**: Open3 for robust external command handling

## Contributing

1. Fork the project
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rake test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Contribution Guidelines

- Maintain test coverage above 90%
- Follow existing code style and patterns
- Update documentation for new features
- Add integration tests for new CLI options
- Ensure thread safety for parallel operations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### v0.9.0 (Current)
- **Configurable color system**: Semantic color coding for configuration values
  - Environment-only values (white)
  - Group values (blue)  
  - Environment overrides group (yellow)
  - Environment matches group (green)
- **Enhanced pattern matching**: Fixed wildcard pattern matching with proper regex anchoring
- **Settings-based configuration**: Color settings configurable via settings.yml
- **Improved output formatting**: Enhanced table formatter with configurable colors

### Key Features
- Multi-environment YAML comparison
- Wildcard pattern matching with proper anchoring
- Secret exposure capability
- Multiple output formats with semantic colors
- Environment group support
- Parallel processing optimization
- Thread-safe singleton architecture
- Advanced caching with Redis/Moneta backends
