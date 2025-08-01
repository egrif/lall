# GitHub Copilot Instructions

## Project Overview

Lall is a Ruby CLI tool for comparing YAML configuration values across multiple LOTUS environments. It provides parallel multi-environment searches with caching, secret management, and flexible output formatting.

## Architecture

**Core Flow**: CLI → Settings Resolution → Lotus Commands → YAML Search → Result Formatting
- `LallCLI` - Main entry point and argument processing
- `Lotus::Runner` - External lotus command wrapper with regional argument logic
- `KeySearcher` - YAML traversal with flat key-value structure (no nesting)
- `CacheManager` - Redis/Moneta dual backend with AES-256-GCM encryption
- `SettingsManager` - 4-tier priority: CLI → ENV → User → Gem defaults
- `TableFormatter` - Output formatting with pivot table support
- `Lotus::Environment` - Represents a LOTUS environment with name, space, region, and application. should encapsulate the environment data and operations
- `Lotus::Group` - Represents Lotus group definitions and values
- `Lotus::EntitySet` - Represents the set of environments we are operating on and any Louts groups they are members of.  Should encapsulate group operations

## Key Patterns

### Value Retrieval Logic
- For an environment we will match to:
    - `configs` section for environment-specific values
    - `secrets` section for environment secrets
    - `group_secrets` section for group-specific secrets
- a 'config` match will select that key-value pair
- a `secrets` match will use the matched string to issue a `get secret` command to the environment to find the value of that secret
- a `group_secrets` match will use the matched string to issue a `get secret` command to the group to find the value of that secret


### Lotus Integration
The external `lotus` CLI is the primary data source. Commands follow specific patterns:
```ruby
# Environment data: lotus view -s \prod -e \env -a greenhouse -G [-r \region]
# Group data: lotus view -s \prod -g \group -a greenhouse [-r \region]  
# Environment Secrets: lotus secret get key -s \prod -e \env -a greenhouse [-r \region]
# Group Secrets: lotus secret get key -s \prod -g \group -a greenhouse [-r \region]
```

Region mapping logic in `Lotus::Runner.get_lotus_args()`:
- `prod*`/`staging*` → s_arg: `prod`
- Environment suffix `s1-99` → region: `use1`
- Environment suffix `s101-199` → region: `euc1`  
- Environment suffix `s201-299` → region: `apse2`

### Threading & Parallelization
**Critical**: All multi-environment and secret fetching uses Ruby threads:
```ruby
# Pattern used throughout codebase
threads = envs.map do |env|
  Thread.new do
    # Fetch data for env
  end
end
threads.each(&:join)
```

### YAML Data Structure (Simplified)
KeySearcher expects **flat structures only** - no nested traversal:
```yaml
configs:
  key: "value"  # Flat key-value pairs
secrets:
  keys: ["key1", "key2"]  # Array of key names
group_secrets:
  keys: ["key1", "key2"]  # Array of key names
```
**Note:** actual examples of YAML data (environment.yam and group.yaml) might be found in the `tmp/reference` directory

Search methods target specific sections: `search_configs_section()`, `search_secrets_section()`, etc.

### Settings Priority System
**Always use SettingsManager** - never direct ENV or config access:
```ruby
@settings = Lall::SettingsManager.new(cli_options)
value = @settings.get('cache.ttl', default_value)
```

Priority: CLI args → ENV vars → `~/.lall/settings.yml` → `config/settings.yml`

### Cache Architecture
Dual backend (Redis preferred, Moneta file fallback) with encryption:
- All SECRET data encrypted with AES-256-GCM before storage
- Cache keys use configurable prefixes for namespace isolation
- Human-readable cache keys (no hashing) for debugging
- Separate secret caching with extended TTL

## Development Workflows

### Testing

All tests must be passing before pushing

```bash
# Unit tests only (excludes integration)
bundle exec rake spec
# or: bundle exec rspec --exclude-pattern='spec/**/*integration*'

# Integration tests (requires lotus CLI)
bundle exec rake integration

# All tests
bundle exec rake test
```
**Test Patterns**:
- Mock `Lotus::Runner` methods in specs (never call real lotus)
- Use `SpecHelpers.sample_yaml_data` for consistent test fixtures
- Integration tests use `xit` for pending (not `skip` or `pending`)

### CI Tests
```bash
# spelling tests
npx cspell .

# linting
bundle exec rubocop
```

### GIT management for new release
- Use feature branches for all changes
- Follow conventional commit messages
- bump version before creating a PR
- remember to update documentation
- never push without all tests passing (including CI tests)

**Version**: Follows semantic versioning in `lib/lall/version.rb`

### Debugging
Set debug flags to see lotus commands:
```bash
export LALL_DEBUG=true
# or use -d/--debug flag
```

## Code Conventions

### Error Handling
Lotus command failures return `nil` - always check:
```ruby
yaml_data = Lotus::Runner.fetch_env_yaml(env)
return nil unless yaml_data
```

### Method Naming
- `fetch_env_yaml()` - fetches environment-specific YAML
- `fetch_group_yaml()` - fetches group-specific YAML  
- Use `_section` suffix for KeySearcher methods: `search_configs_section()`

### Threading Safety
Use mutex for shared result aggregation:
```ruby
mutex = Mutex.new
results = {}
# In thread:
mutex.synchronize { results[key] = value }
```

### Color Coding System
KeySearcher applies semantic colors:
- `:blue` - Environment matches group value
- `:yellow` - Environment overrides group value
- `:green` - Group value with no environment override
- `:white` - Environment-only value

## External Dependencies

**Required**: `lotus` CLI must be installed and configured
**Optional**: Redis server (will fallback to file cache)
**Ruby**: 3.1+ required

## File Organization

- `lib/lall/` - Core CLI components
- `lib/lotus/` - External command wrappers
- `spec/` - RSpec tests (unit + integration separation)
- `config/settings.yml` - Gem defaults (groups, cache config)
- `bin/lall` - Executable entry point
