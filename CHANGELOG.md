# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2025-07-30

### Added
- Group listing functionality: `lall -g list` displays all available groups and their environments
- Enhanced help documentation for the `-g` option to mention the list functionality

### Changed
- Improved validation logic to allow `-g list` without requiring a search string
- Updated test suite to include comprehensive coverage for group listing feature

## [0.1.1] - 2025-07-30

### Added
- Comprehensive spell checking with cspell configuration
- Enhanced security scanning with git-secrets whitelist patterns
- Complete test coverage with 117 test cases across all components

### Changed
- Updated Ruby version requirements to 3.1+ for better compatibility and modern language features
- Modernized CI/CD pipeline to use Ruby 3.1-3.3 matrix
- Fixed gemspec to dynamically read version from `lib/lall/version.rb`
- Updated RuboCop configuration for Ruby 3.1+ features
- Major code refactoring to reduce complexity and improve maintainability:
  - Extracted methods in CLI, KeySearcher, and TableFormatter classes
  - Reduced parameter lists and improved code readability
  - Applied method extraction patterns to break down complex operations

### Fixed
- Resolved 547 RuboCop violations through systematic code improvements
- Resolved hardcoded file paths in test fixtures that caused CI failures
- Fixed test suite compatibility across different environments
- Corrected release workflow configuration for proper gem publishing
- Applied modern Ruby syntax improvements (anonymous block forwarding)
- Eliminated security scan false positives with comprehensive whitelist

## [0.1.0] - 2024-01-XX

### Added
- Initial release of lall CLI tool
- Multi-environment YAML configuration comparison
- Wildcard pattern matching with `*` support
- Environment group configuration in `config/settings.yml`
- Multiple output formats:
  - Standard key-based table
  - Path-included table (`-p` flag)
  - Pivoted table (`-v` flag, environments as rows)
- Secret management capabilities:
  - Optional secret value exposure (`-x/--expose` flag)
  - Support for both environment and group secrets
  - Parallel secret fetching for performance
- Performance optimizations:
  - Parallel environment data fetching
  - Threaded secret retrieval
  - Lotus server connectivity pre-check
- CLI options:
  - `-s/--string`: Search pattern (required, supports wildcards)
  - `-e/--env`: Comma-separated environment list
  - `-g/--group`: Predefined environment group
  - `-p/--path`: Include full path in output
  - `-i/--insensitive`: Case-insensitive search
  - `-v/--pivot`: Pivot table format
  - `-t/--truncate`: Value truncation control
  - `-x/--expose`: Expose actual secret values
  - `-d/--debug`: Debug mode with lotus command output
- Lotus integration:
  - Automatic space/region argument determination
  - Support for US (use1), EU (euc1), and APAC (apse2) regions
  - Robust error handling for command failures
- Architecture:
  - Modular design following Single Responsibility Principle
  - Clean separation of concerns between CLI, search, formatting, and external API layers
  - Thread-safe parallel processing with proper synchronization
  - Comprehensive error handling and graceful degradation

### Technical Details
- Ruby 2.7+ compatibility
- Dependencies: yaml, optparse, open3 (all built-in)
- External dependency: lotus CLI tool
- Thread-safe parallel processing using Ruby's Thread class with Mutex synchronization
- YAML parsing using Ruby's built-in YAML library
- External command execution using Open3 for robust process management
