# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2025-07-31

### Added
- **Color-Coded Value Display System**: Enhanced visual representation that shows value relationships at a glance
  - **White**: Environment values with no group override (pure environment configuration)
  - **Yellow**: Environment values that override group values (environment-specific overrides)  
  - **Green**: Group values with no environment override (standard group configuration)
  - **Blue**: Group values that have matching environment override (consistent values across both)
- **Advanced Table Formatting**: Professional table output with proper column alignment
  - Fixed ANSI color code interference with table column calculations
  - Manual padding calculations to handle color escape sequences correctly
  - Consistent spacing and alignment across all output formats
- **RuboCop Compliance**: Zero code quality violations for CI/CD pipeline requirements
  - Strategic method extraction and refactoring for maintainability
  - Comprehensive code quality standards while preserving functionality
  - Clean, professional codebase ready for production deployment

### Changed
- **Enhanced Key Display Logic**: Sophisticated value relationship determination with color coding
- **Improved Table Renderer**: Better handling of ANSI escape sequences in column width calculations
- **Code Quality**: Refactored complex methods into smaller, focused functions
- **Test Coverage**: Updated test expectations to match enhanced color display functionality

### Technical Details
- Enhanced `KeySearcher` with sophisticated color determination logic and helper methods
- Upgraded `TableFormatter` with ANSI-aware column alignment and manual padding calculations
- Applied strategic RuboCop compliance with method extraction and targeted disable comments
- Maintained 100% test coverage (153 examples passing) throughout all enhancements
- Production-ready codebase with zero static analysis violations

## [0.4.0] - 2025-07-31

### Added
- **Cache Prefix Support**: Configurable cache key prefixes for namespace isolation
  - Default prefix: `lall-cache`
  - Configurable via `--cache-prefix`, `LALL_CACHE_PREFIX` environment variable, or settings file
  - Enables multiple applications to share cache storage without conflicts
- **Selective Cache Clearing**: Cache clear operations now respect prefix boundaries
  - Only cache entries with matching prefix are cleared
  - Prevents accidental clearing of other applications' cache data
- **Enhanced Cache Backend**: Upgraded from custom file-based cache to professional Moneta gem
  - Redis primary backend with Moneta file-based fallback
  - Improved reliability and performance
  - Better error handling and graceful fallbacks
- **Cache Statistics Enhancement**: Cache stats now include current prefix information

### Changed
- **Cache Architecture**: Replaced complex multi-backend system with Redis + Moneta approach
- **Cache Key Generation**: All cache keys now include configurable prefix (`prefix:hash`)
- **Settings Integration**: Cache prefix fully integrated into settings priority resolution system
- **Documentation**: Updated README with comprehensive cache prefix examples and configuration

### Technical Details
- Added `moneta` gem dependency for professional key-value store management
- Enhanced cache manager with prefix-aware operations for both Redis and Moneta backends
- Added comprehensive test coverage for cache prefix functionality
- Improved code quality with simplified cache backend architecture

## [0.3.0] - 2025-07-30

### Added
- **Settings Priority Resolution System**: Comprehensive configuration management with priority order:
  1. Command line arguments (highest priority)
  2. Environment variables
  3. User settings file (`~/.lall/settings.yml`)
  4. Gem default settings (lowest priority)
- **User Settings Initialization**: New `--init-settings` command to create a personalized settings file
- **Environment Variable Support**: Full support for environment variables like `LALL_CACHE_TTL`, `LALL_DEBUG`, etc.
- **Settings Debug Tool**: New `--debug-settings` command to show how settings are resolved
- **Enhanced Settings Manager**: Comprehensive `SettingsManager` class with smart resolution logic
- **Well-Commented Settings File**: Auto-generated user settings file includes helpful comments and examples

### Changed
- CLI initialization refactored to use the new settings priority system
- Cache manager now integrates with the settings resolution system
- All configuration options now support the four-tier priority resolution
- Settings are resolved once at startup for better performance

### Technical Details
- Added `Lall::SettingsManager` class with comprehensive priority resolution
- Enhanced CLI option parsing to separate raw options from resolved options
- Added boolean parsing for environment variables (true/false/1/0)
- Comprehensive test coverage for all settings resolution scenarios

## [0.2.0] - 2025-07-30

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
