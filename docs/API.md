# API Documentation

## Core Classes

### LallCLI

Main entry point for the command-line interface.

#### Methods

##### `initialize(argv)`
Parses command-line arguments using OptionParser.

**Parameters:**
- `argv` (Array): Command-line arguments array

**Parsed Options:**
- `:string` - Search pattern (required)
- `:env` - Comma-separated environments
- `:group` - Environment group name
- `:path_also` - Include path in output
- `:insensitive` - Case-insensitive search
- `:pivot` - Pivot table format
- `:truncate` - Value truncation length
- `:expose` - Expose secret values
- `:debug` - Debug mode

##### `run()`
Executes the main application workflow.

**Process:**
1. Validates arguments
2. Resolves environments from groups or env list
3. Pings lotus servers
4. Fetches environment data in parallel
5. Formats and displays results

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments or unknown group

##### `fetch_env_results(envs)`
Fetches YAML data from multiple environments in parallel.

**Parameters:**
- `envs` (Array): List of environment names

**Returns:**
- `Hash` - Environment results keyed by environment name

---

### KeySearcher

Handles YAML traversal and key pattern matching.

#### Class Methods

##### `match_key?(key_str, search_str)`
Tests if a key matches a search pattern.

**Parameters:**
- `key_str` (String): Key to test
- `search_str` (String): Search pattern (supports `*` wildcards)

**Returns:**
- `Boolean` - True if key matches pattern

**Examples:**
```ruby
KeySearcher.match_key?('api_token', 'api_*')     # => true
KeySearcher.match_key?('database_url', '*_url')  # => true  
KeySearcher.match_key?('timeout', 'api_*')       # => false
```

##### `search(obj, search_str, path=[], results=[], insensitive=false, **options)`
Recursively searches YAML structure for matching keys.

**Parameters:**
- `obj` (Hash|Array|Object): YAML data to search
- `search_str` (String): Search pattern
- `path` (Array): Current path in YAML structure
- `results` (Array): Accumulator for results
- `insensitive` (Boolean): Case-insensitive matching
- `**options` (Hash): Additional options
  - `:env` (String): Environment name for secret fetching
  - `:expose` (Boolean): Whether to fetch actual secret values
  - `:debug` (Boolean): Debug mode

**Returns:**
- `Array` - Array of result hashes with `:path`, `:key`, `:value`

##### `handle_secret_match(results, secret_jobs, path, key, value, expose, env, idx: nil)`
Handles matches for secret keys, optionally queuing secret fetch jobs.

**Parameters:**
- `results` (Array): Results accumulator
- `secret_jobs` (Array): Secret fetch jobs accumulator  
- `path` (Array): Current YAML path
- `key` (String): Matched key
- `value` (Object): Key value
- `expose` (Boolean): Whether to expose secret values
- `env` (String): Environment name
- `idx` (Integer, optional): Array index for array elements

##### `find_group(obj)`
Extracts group name from YAML root object.

**Parameters:**
- `obj` (Hash): YAML root object

**Returns:**
- `String|nil` - Group name or nil if not found

---

### TableFormatter

Formats search results into readable table output.

#### Methods

##### `initialize(columns, envs, env_results, options)`
Creates a new table formatter.

**Parameters:**
- `columns` (Array): Column definitions
- `envs` (Array): Environment names
- `env_results` (Hash): Search results by environment
- `options` (Hash): Formatting options

##### `print_table()`
Prints pivoted table format (environments as rows).

##### `print_key_table(all_keys, envs, env_results)`
Prints standard key-based table format.

**Parameters:**
- `all_keys` (Array): All unique keys found
- `envs` (Array): Environment names
- `env_results` (Hash): Results by environment

##### `print_path_table(all_paths, all_keys, envs, env_results)`
Prints table with path information included.

**Parameters:**
- `all_paths` (Array): All unique paths found
- `all_keys` (Array): All unique keys found
- `envs` (Array): Environment names  
- `env_results` (Hash): Results by environment

#### Class Methods

##### `truncate_middle(str, max_len)`
Truncates string in the middle with ellipsis.

**Parameters:**
- `str` (String): String to truncate
- `max_len` (Integer): Maximum length

**Returns:**
- `String` - Truncated string with `...` in middle

**Examples:**
```ruby
TableFormatter.truncate_middle('very_long_string', 10)
# => 'ver...ring'
```

---

### Lotus::Runner

Executes lotus commands and parses responses.

#### Class Methods

##### `fetch_env_yaml(env)`
Fetches YAML configuration for an environment.

**Parameters:**
- `env` (String): Environment name

**Returns:**
- `Hash|nil` - Parsed YAML data or nil on failure

**Lotus Command:**
```bash
lotus view -s <space> -e <env> -a greenhouse -G [-r <region>]
```

##### `secret_get(env, secret_key, group: nil)`
Fetches a single secret value.

**Parameters:**
- `env` (String): Environment name
- `secret_key` (String): Secret key name
- `group` (String, optional): Group name for group secrets

**Returns:**
- `String|nil` - Secret value or nil on failure

**Lotus Command:**
```bash
# Environment secret:
lotus secret get <key> -s <space> -e <env> -a greenhouse [-r <region>]

# Group secret:  
lotus secret get <key> -s <space> -g <group> -a greenhouse [-r <region>]
```

##### `secret_get_many(env, secret_keys)`
Fetches multiple secrets in parallel.

**Parameters:**
- `env` (String): Environment name
- `secret_keys` (Array): Array of secret key names

**Returns:**
- `Hash` - Hash of key => value pairs

##### `ping(env)`
Tests connectivity to lotus server for environment.

**Parameters:**
- `env` (String): Environment name

**Returns:**
- `Boolean` - True if ping successful

##### `get_lotus_args(env)`
Determines lotus command arguments from environment name.

**Parameters:**
- `env` (String): Environment name

**Returns:**
- `Array` - `[space_arg, region_arg]`

**Logic:**
- Space: `prod` for prod/staging environments, otherwise env name
- Region: Based on numeric suffix (s1-99→use1, s101-199→euc1, s201-299→apse2)

---

### Lotus::Environment

Models environment data and provides convenience methods.

#### Methods

##### `initialize(yaml_hash)`
Creates environment instance from YAML data.

##### `group()`
Returns the environment's group name.

##### `configs()`
Returns the configs hash (defaults to empty hash).

##### `secret_keys()`
Returns array of environment secret keys.

##### `group_secret_keys()`
Returns array of group secret keys.

#### Class Methods

##### `from_yaml(yaml_obj)`
Factory method to create instance from YAML.

##### `from_args(environment:, space: nil, region: nil, application: 'greenhouse')`
Factory method to create instance with computed space/region.

---

### Lotus::Group

Models group data from YAML.

#### Methods

##### `initialize(yaml_hash)`
Creates group instance from YAML data.

##### `configs()`
Returns the configs hash.

##### `secrets()`
Returns array of secret keys.

---

### Cli::Options

Configuration object with default values and dynamic attribute access.

#### Methods

##### `initialize(opts = {})`
Creates options object merging provided options with defaults.

**Defaults:**
```ruby
{
  path_also: false,
  insensitive: false, 
  pivot: false,
  truncate: 40,
  expose: false,
  debug: false
}
```

##### Dynamic Attribute Access
Options can be accessed as methods:

```ruby
options = Cli::Options.new(truncate: 100)
options.truncate  # => 100
options.debug     # => false
```

## Error Handling

### Command Failures
- Lotus command failures return `nil` and log warnings to stderr
- Missing environments are handled gracefully
- Network timeouts are caught and logged

### Validation Errors
- Missing required arguments trigger usage display and exit(1)
- Unknown groups trigger error message and exit(1)
- Mutually exclusive options trigger error and exit(1)

### Thread Safety
- Mutex synchronization for shared result objects
- Individual thread failures don't affect other threads
- Proper resource cleanup on thread completion

---

### Lall::CacheManager

Thread-safe singleton for managing Redis/Moneta cache operations with encryption.

#### Class Methods

##### `instance(options = {})`
Returns the singleton CacheManager instance.

**Parameters:**
- `options` (Hash): Configuration options (only used on first call or if instance needs recreation)
  - `:redis_url` (String): Redis connection URL
  - `:cache_dir` (String): Directory for file-based cache
  - `:cache_prefix` (String): Cache key prefix
  - `:ttl` (Integer): Time-to-live in seconds
  - `:enabled` (Boolean): Enable/disable caching

**Returns:**
- `CacheManager` - Singleton instance

##### `reset!`
Clears the singleton instance (primarily for testing).

#### Instance Methods

##### `get_env_data(environment)`
Retrieves cached environment data.

**Parameters:**
- `environment` (Lotus::Environment): Environment instance

**Returns:**
- `Hash|nil` - Cached environment data or nil if not found

##### `set_env_data(environment, data)`
Caches environment data.

**Parameters:**
- `environment` (Lotus::Environment): Environment instance
- `data` (Hash): Environment data to cache

##### `get_group_data(group_name, application)`
Retrieves cached group data.

**Parameters:**
- `group_name` (String): Group name
- `application` (String): Application name

**Returns:**
- `Hash|nil` - Cached group data or nil if not found

---

### Lall::SettingsManager

Thread-safe singleton for managing configuration settings with priority-based resolution.

#### Class Methods

##### `instance(cli_options = {})`
Returns the singleton SettingsManager instance.

**Parameters:**
- `cli_options` (Hash): CLI options (only used on first call or if instance needs recreation)

**Returns:**
- `SettingsManager` - Singleton instance

##### `reset!`
Clears the singleton instance (primarily for testing).

#### Instance Methods

##### `get(key, default = nil)`
Retrieves a setting value using priority-based resolution.

**Priority Order:**
1. CLI options
2. Environment variables
3. User settings (`~/.lall/settings.yml`)
4. Gem default settings

**Parameters:**
- `key` (String): Setting key (supports dot notation for nested keys)
- `default` - Default value if key not found

**Returns:**
- Setting value or default

**Examples:**
```ruby
settings = Lall::SettingsManager.instance
settings.get('cache.ttl', 3600)        # => 3600 (from settings or default)
settings.get('groups.staging')         # => ['staging', 'staging-s2', ...]
```

---

### Lotus::Environment

Represents a LOTUS environment with caching and data fetching capabilities.

#### Methods

##### `initialize(name, space: nil, region: nil, application: 'greenhouse', cache_manager: nil, entity_set: nil)`
Creates a new Environment instance.

**Parameters:**
- `name` (String): Environment name
- `space` (String): Environment space (defaults to auto-detected)
- `region` (String): Environment region (defaults to auto-detected)
- `application` (String): Application name (defaults to 'greenhouse')
- `cache_manager` (CacheManager): Cache manager instance (defaults to singleton)
- `entity_set` (EntitySet): Parent entity set reference

##### `fetch`
Loads environment data with cache-first architecture.

**Process:**
1. Returns existing data if already loaded
2. Checks cache for environment data
3. Falls back to lotus command if cache miss
4. Loads associated group data if present
5. Caches results for future use

**Returns:**
- `Hash|nil` - Environment data structure or nil if fetch fails

##### `configs`
Returns configuration key-value pairs.

**Returns:**
- `Hash` - Configuration data

**Raises:**
- `NoMethodError` - If data not loaded via fetch first

##### `secret_keys`
Returns array of environment secret keys.

**Returns:**
- `Array<String>` - Secret key names

##### `group_secret_keys`
Returns array of group secret keys.

**Returns:**
- `Array<String>` - Group secret key names

---

### Lotus::EntitySet

Manages collections of environments with group operations and settings integration.

#### Methods

##### `initialize(entities_or_settings)`
Creates an EntitySet with dual initialization modes.

**Parameters:**
- `entities_or_settings` (Array|SettingsManager): 
  - `Array<Environment>`: Existing environment instances
  - `SettingsManager`: Settings object for auto-creation

**Automatic Environment Creation:**
When initialized with SettingsManager, automatically creates Environment instances for all groups defined in settings.

##### `entities`
Returns all environment instances.

**Returns:**
- `Array<Lotus::Environment>` - All environments in the set

##### `groups`
Returns unique group names from all environments.

**Returns:**
- `Array<String>` - Unique group names

**Examples:**
```ruby
# Traditional initialization
envs = [env1, env2, env3]
entity_set = Lotus::EntitySet.new(envs)

# Settings-based initialization
settings = Lall::SettingsManager.instance
entity_set = Lotus::EntitySet.new(settings)  # Auto-creates environments
```

---

### Lotus::Group

Represents a LOTUS group with caching capabilities.

#### Class Methods

##### `from_args(name:, application: 'greenhouse', cache_manager: nil)`
Creates a Group instance with specified parameters.

**Parameters:**
- `name` (String): Group name
- `application` (String): Application name
- `cache_manager` (CacheManager): Cache manager instance

#### Instance Methods

##### `fetch`
Loads group data with caching support.

**Returns:**
- `Hash|nil` - Group data or nil if fetch fails

---

## Performance Characteristics

### Parallel Processing
- Environment fetching: One thread per environment
- Secret fetching: One thread per secret key
- Typical speedup: 5-10x for multiple environments

### Memory Usage
- YAML data cached per environment during processing
- Results accumulated in memory before display
- Memory usage scales linearly with data size

### Network Efficiency
- Single ping per unique lotus space
- Parallel secret fetches reduce total request time
- Connection reuse within lotus CLI
