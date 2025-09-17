# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] - 2025-09-17

### Added
- **Export Functionality**: Multiple output formats with file export capabilities
  - Added `--format`/`-f` option supporting CSV, JSON, YAML, and TXT formats
  - Added `--output-file`/`-o` option to write results to files instead of stdout
  - CSV format: Comma-separated values with proper header row
  - JSON format: Hierarchical structure with environments as top-level keys
  - YAML format: Clean YAML structure for configuration management workflows
  - TXT format: Tab-separated values for easy parsing and processing
  - All formats support file output with success confirmation messages

### Fixed
- **Critical Bug**: Fixed NoMethodError in fetch_results_from_entity_set
  - Fixed undefined method 'results' error when using entity-based search
  - Implemented proper search logic that builds search data for each environment
  - Added proper integration between EntitySet and CLI search functionality
  - Fixed syntax errors and method structure issues in CLI class
  - Ensured all tests pass with 68 examples and 0 failures

## [0.11.2] - 2025-09-16

### Fixed
- **Critical Bug**: Fixed secret exposure with application flag
  - Secret values were not being exposed when using `-a`/`--application` flag with `-x`/`--expose` option
  - Problem was in `build_search_data_for_entity()` and `add_group_data_to_search_data()` methods
  - Both environment and group secrets were missing required 'keys' array when `@options[:expose]` was true
  - The `perform_search()` method requires the 'keys' array to find secrets to search through
  - Now 'keys' array is always added regardless of expose setting
  - Added comprehensive integration tests to prevent regression

### Added
- **Test Coverage**: New integration tests for secret exposure functionality
  - Added tests for secret exposure with application flag in both expose and non-expose modes
  - Ensures secrets are properly exposed with `-a app -x` and show placeholders with `-a app`

## [0.11.1] - 2025-08-15

### Fixed
- **Test Infrastructure**: Complete overhaul of EntitySet test suite
  - Fixed all failing EntitySet tests by rewriting them to match actual implementation behavior
  - Added comprehensive test coverage with 20+ test cases covering initialization, entity management, and data operations
  - Improved test reliability with proper mocking and dependency management
  - All tests now pass consistently (117 examples, 0 failures)

### Improved  
- **Code Quality**: Enhanced project maintainability
  - Removed unnecessary and empty test files causing linting issues
  - Cleaned up project structure and file organization
  - Better separation of test concerns and proper validation patterns
- **Development Experience**: More reliable CI/CD pipeline
  - Consistent test execution and validation
  - Improved development workflow with reliable test feedback

## [0.11.0] - 2025-08-13

### Changed
- **Search Argument**: Renamed the primary search argument from `-s`/`--string` to `-m`/`--match` to more accurately reflect its support for glob patterns.
- **Environment Definition**: Environments can now be specified using a `name:space:region` format, allowing for more flexible and precise targeting.

### Improved
- **Test Infrastructure**: Complete overhaul of EntitySet test suite with comprehensive coverage
  - Fixed all failing tests by aligning them with actual implementation behavior
  - Added 20+ test cases covering initialization, entity management, and data operations
  - Improved test reliability with proper mocking and validation
- **Code Quality**: Removed unnecessary files and improved project structure

## [0.10.0] - 2025-08-11

### Added
- **Settings overview command**: New `--show-settings` option displays comprehensive view of all resolved settings
  - Shows search options, output options, color settings, cache configuration
  - Displays available environment groups
  - Includes settings resolution priority information
- **Enhanced cache statistics**: `--cache-stats` now shows detailed entity counts
  - Displays count of cached environments, groups, environment secrets, and group secrets
  - Provides better insight into cache utilization and performance

### Improved
- **Pattern matching**: Enhanced wildcard pattern matching with better error handling
- **Search logic**: Improved key matching using `File.fnmatch` for more robust pattern support
- **Cache entity counting**: Added intelligent parsing of cache keys to categorize different entity types

## [0.9.0] - 2025-08-10

### Added
- **Configurable color system**: Semantic color coding for configuration values
  - Environment-only values display in white
  - Group values display in blue
  - Environment overrides group display in yellow
  - Environment matches group display in green
- **Enhanced pattern matching**: Fixed wildcard pattern matching with proper regex anchoring
- **Settings-based configuration**: Color settings configurable via settings.yml and user settings
- **Improved output formatting**: Enhanced table formatter with configurable ANSI colors

### Fixed
- **Pattern matching bug**: Fixed wildcard patterns (e.g., "SOLR*") incorrectly matching keys containing the pattern anywhere (e.g., "SIDEKIQ_SOLR_*")
- **Regex anchoring**: Properly anchor wildcard patterns to match from start/end of strings

### Changed
- **TableFormatter**: Enhanced constructor to accept settings for dynamic color configuration
- **CLI color logic**: Improved color determination logic for semantic value display
- **Settings integration**: Full integration of color settings throughout the formatting pipeline

## [0.8.0] - 2025-01-27

### Added
- Entity-based search architecture with direct CLI search implementation
- Settings-based configurable secret placeholder (default: '{SECRET}')
- Enhanced secret exposure functionality with -x flag showing actual values

### Changed
- **BREAKING**: Eliminated KeySearcher class in favor of entity-based search
- Moved search logic directly into CLI class for simplified architecture
- Updated all tests to match new entity-based architecture (161 unit + 9 integration tests)
- Improved secret value handling with proper exposure control

### Fixed
- Runner.fetch bug with Array data type handling in cached data
- Secret exposure logic to correctly display actual values with -x flag
- Thread-safe data handling in parallel entity processing

### Internal
- Comprehensive test suite updates for new architecture
- Enhanced error handling for Array data types in Runner
- Improved test coverage for secret functionality

## [0.7.0] - 2025-08-02

### Added
- **Thread-Safe Singleton Pattern**: Implemented comprehensive singleton architecture for core managers
  - **CacheManager**: Thread-safe singleton with mutex protection and testing isolation
  - **SettingsManager**: Thread-safe singleton with CLI option support and reset capability
  - Singleton instances can be reset for testing isolation via `reset!` method
- **Enhanced Lotus::EntitySet**: Comprehensive entity management with dual initialization modes
  - **Traditional Mode**: Initialize with array of existing Environment instances
  - **Settings Mode**: Auto-create environments from settings configuration groups
  - Bidirectional references between EntitySet and Environment instances
  - Automatic group membership detection and management
- **Environment#fetch Method**: Complete implementation with cache-first architecture
  - Cache-first data loading with intelligent fallback to lotus commands
  - Automatic group data loading and caching when environment belongs to a group
  - Comprehensive YAML data processing and validation
  - Thread-safe operation with singleton cache manager integration
- **Comprehensive Test Coverage**: 210 tests with clean error handling
  - Full coverage of singleton functionality with proper test isolation
  - Comprehensive mocking to eliminate all external dependencies during testing
  - Clean test output with all warnings and errors suppressed
  - Performance maintained with intelligent caching reducing external calls

### Changed
- **API Simplification**: Eliminated deep parameter passing through singleton pattern
  - CacheManager and SettingsManager now accessible via singleton instances
  - Reduced method signatures and simplified object initialization
  - Backward compatibility maintained for all existing APIs
- **Improved Cache Architecture**: Proper separation of concerns achieved
  - Cache key construction moved to CacheManager for consistency
  - Environment-specific cache methods for better organization
  - Enhanced error handling and data validation throughout
- **Enhanced Error Suppression**: Clean development experience with comprehensive mocking
  - All lotus command errors properly mocked in tests
  - Moneta warnings suppressed for clean test output
  - TEST_MODE detection for conditional warning suppression

### Technical
- **Thread-Safe Implementation**: All singleton instances use mutex protection
- **Class Instance Variables**: Proper encapsulation using @instance instead of @@instance
- **Comprehensive Integration**: EntitySet, Environment, and cache managers work seamlessly together
- **Performance Optimization**: Intelligent caching with cache-first architecture
- **Code Quality**: All RuboCop and CSpell checks passing with clean formatting
- **Robust Testing**: 210 comprehensive tests with zero failures and clean output

## [0.6.1] - 2025-08-01

### Fixed
- **Environment#space Method**: Fixed operator precedence bug where explicit space parameter was ignored
- **Environment#space Method**: Fixed undefined variable reference (environment → @name)
- **Code Alignment**: Removed non-existent group_configs operations from CLI and KeySearcher to match actual lotus YAML structure
- **Environment Class Interface**: Completely redesigned Environment class constructor to match expected API
- **Lotus Runner Commands**: Added missing -G flag to lotus view commands for proper functionality
- **Method Name Alignment**: Fixed fetch_env_yaml → fetch_yaml method name consistency

### Changed
- **KeySearcher Refactoring**: Replaced recursive search with direct section targeting for better performance and clarity
- **Comprehensive Documentation**: Added detailed GitHub Copilot instructions for AI agent development workflows
- **Environment Class Architecture**: New constructor signature `(name, space:, region:, application:)` with proper attribute handling

### Technical
- **Complete Environment Class Rewrite**: Proper implementation with expected constructor and method signatures
- **All 144 tests passing**: Full test suite compatibility achieved with 100% pass rate
- **Code style compliance**: All RuboCop and spelling checks passing
- **Proper Git Workflow**: Feature branch development following project conventions

## [0.6.0] - 2025-07-31

### Added
- **Human-Readable Cache Keys**: Complete redesign of cache key format for transparency and debugging
  - **New Format**: `lall-cache.ENV.prod-s9.prod.use1` (dot-separated, human-readable)
  - **Old Format**: `lall-cache:a1b2c3d4...` (SHA256 hashed, opaque)
  - Cache keys now follow structured format: `<prefix>.<type>.<environment_or_group>.<space>.<region>[.<secret_key>]`
- **Separate Secret Caching System**: Individual encrypted cache entries for each secret
  - **Environment Secrets**: `lall-cache.ENV-SECRET.prod-s9.prod.use1.DATABASE_MAIN_URL`
  - **Group Secrets**: `lall-cache.GROUP-SECRET.core-group.prod.use1.API_KEY`
  - Secrets cached independently for better performance and granular access
- **Enhanced Cache Statistics**: Comprehensive cache size reporting with human-readable formatting
  - Total cache keys count and prefixed keys count
  - Cache size in bytes with automatic unit conversion (B, KB, MB, GB, TB)
  - Example: "Cache Size: 22 keys, 218.1 KB"
- **Region Defaulting**: All cache keys now include region with 'use1' as default fallback
  - Ensures consistent cache key format across all environments
  - Backward compatibility for environments without explicit regions

### Changed
- **Cache Key Generation**: Removed SHA256 hashing in favor of human-readable dot notation
- **Secret Caching Architecture**: Secrets now cached separately from environment data
- **Cache Statistics Display**: Enhanced `--cache-stats` output with size information and formatting
- **Cache Manager Parameter Passing**: Fixed recursive search calls to properly pass cache manager

### Fixed
- **Cache Manager Parameter Bug**: Fixed issue where cache manager wasn't passed through recursive search calls
- **Secret Caching**: Resolved problem where secrets weren't being cached under their own keys
- **Region Consistency**: Ensured all cache keys include proper region information

### Security
- **AES-256-GCM Encryption**: Secret values encrypted with industry-standard encryption
- **Selective Encryption**: Only secret values encrypted, cache keys remain human-readable
- **Key Management**: Secure 32-byte random key generation and storage

### Technical Details
- Removed `digest` dependency as SHA256 hashing is no longer used
- Enhanced `CacheManager` with size calculation methods for Redis and Moneta backends
- Updated `KeySearcher` with proper parameter passing and separate secret processing
- Added comprehensive debug output for secret caching operations
- Maintained 100% test coverage (153 examples passing) throughout major refactoring

### Breaking Changes
- **Cache Key Format**: Existing cache entries will be regenerated with new human-readable format
- **Cache Invalidation**: All existing cache will be cleared on first run with new version

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
