# Cache Purging Example

This demonstrates the new cache purging functionality that allows you to clear
all cache entries related to a specific Environment or Group entity.

## Usage Examples

```ruby
require 'lotus/environment'
require 'lotus/group'

# Create an environment
env = Lotus::Environment.new('prod-s1', application: 'greenhouse')

# Fetch some data (this will cache environment data and any secrets)
env.fetch
# Note: Entity-based search is now handled within CLI class, not KeySearcher

# Clear all cache entries related to this environment
# This will remove:
# - Environment data cache
# - All secret cache entries for this environment
env.clear_cache

# Create a group
group = Lotus::Group.new('shared-config', application: 'greenhouse')

# Fetch group data (this will cache group data and any secrets)
group.fetch
# Note: Entity-based search is now handled within CLI class

# Clear all cache entries related to this group
# This will remove:
# - Group data cache
# - All secret cache entries for this group
group.clear_cache

# You can also purge directly through the cache manager
cache_manager = Lall::CacheManager.instance
cache_manager.purge_entity(env)    # Same as env.clear_cache
cache_manager.purge_entity(group)  # Same as group.clear_cache
```

## What Gets Purged

### For Environments:
- Environment data cache: `env:environment_name:application`
- Secret cache keys: `ENV-SECRET.environment_name.space.region.secret_key`

### For Groups:
- Group data cache: `group:group_name:application`
- Secret cache keys: `GROUP-SECRET.group_name.space.region.secret_key`

## Benefits

1. **Selective Cache Invalidation**: Instead of clearing the entire cache, you can now clear only the entries related to a specific entity
2. **Memory Management**: Helps manage cache size by removing stale or unnecessary data
3. **Fresh Data**: Ensures that subsequent fetches will get fresh data from the Lotus backend
4. **Testing**: Useful for test cleanup and isolation

## Error Handling

The method validates the entity type and will raise an `ArgumentError` if you pass an unsupported entity type:

```ruby
cache_manager.purge_entity("invalid")  # Raises ArgumentError
```

If caching is disabled, the method returns `false` without error.
