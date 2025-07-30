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
- **Customizable output**: Truncation control, case-insensitive search options
- **Debug support**: Built-in debugging capabilities with detailed command output
- **Modular architecture**: Clean, maintainable code following Single Responsibility Principle

## Installation

### Prerequisites

- Ruby 2.7 or higher
- The `lotus` command must be available in your PATH
- Access to the target environments through the lotus CLI

### Install from source

```bash
git clone https://github.com/egrif/lall.git
cd lall
bundle install
gem build lall.gemspec
gem install lall-0.1.0.gem
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
lall -s STRING [-e ENV[,ENV2,...]] [-g GROUP] [OPTIONS]
```

**Required arguments:**
- `-s, --string=STRING` : String to search for in YAML keys (supports wildcards with `*`)
- Either `-e, --env=ENV` OR `-g, --group=GROUP` (mutually exclusive)

### Command Line Options

| Option | Long Form | Description | Default |
|--------|-----------|-------------|---------|
| `-s` | `--string=STRING` | String to search for in YAML keys (required, supports `*` wildcards) | |
| `-e` | `--env=ENV` | Comma-separated environment(s) to search | |
| `-g` | `--group=GROUP` | Predefined group of environments | |
| `-p` | `--path` | Include the full path column in output | `false` |
| `-i` | `--insensitive` | Case-insensitive key search | `false` |
| `-v` | `--pivot` | Pivot table (environments as rows, keys as columns) | `false` |
| `-t[LEN]` | `--truncate[=LEN]` | Truncate values longer than LEN characters | `40` |
| `-x` | `--expose` | Expose actual secret values (fetches from lotus) | `false` |
| `-d` | `--debug` | Enable debug output (shows lotus commands) | `false` |

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

## Configuration

### Environment Groups

Edit `config/settings.yml` to define custom environment groups:

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

- **`LallCLI`**: Main entry point, argument parsing, and workflow orchestration
- **`KeySearcher`**: YAML traversal, pattern matching, and secret handling
- **`TableFormatter`**: Output formatting in multiple styles
- **`Lotus::Runner`**: External lotus command execution and response parsing
- **`Lotus::Environment`**: Environment data modeling and region logic
- **`Cli::Options`**: Configuration object with sensible defaults

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
- ✅ YAML traversal and key matching algorithms  
- ✅ All output formatting options
- ✅ Secret fetching and parallel processing
- ✅ Lotus command construction and parsing
- ✅ Error handling and edge cases
- ✅ Environment group configuration
- ✅ Integration workflows

## Architecture

### Data Flow

```
1. CLI Argument Parsing (LallCLI)
     ↓
2. Environment Resolution (groups → env list)  
     ↓
3. Lotus Ping (connectivity check)
     ↓  
4. Parallel Environment Fetching (Lotus::Runner.fetch_yaml)
     ↓
5. YAML Search & Secret Resolution (KeySearcher)
     ↓
6. Result Aggregation & Formatting (TableFormatter)
     ↓
7. Output Display
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

### v0.1.0 (Current)
- Initial release
- Multi-environment YAML comparison
- Wildcard pattern matching
- Secret exposure capability
- Multiple output formats
- Environment group support
- Parallel processing optimization
