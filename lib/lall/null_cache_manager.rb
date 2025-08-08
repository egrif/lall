# frozen_string_literal: true

module Lall
  # Null object pattern for cache manager
  # Used when caching is disabled or cache initialization fails
  class NullCacheManager
    # rubocop:disable Naming/PredicateMethod
    def get(_key, is_secret: false) # rubocop:disable Lint/UnusedMethodArgument
      nil
    end

    def set(_key, _value, is_secret: false) # rubocop:disable Naming/PredicateMethod, Lint/UnusedMethodArgument
      false
    end

    def delete(_key) # rubocop:disable Naming/PredicateMethod
      false
    end

    def clear # rubocop:disable Naming/PredicateMethod
      false
    end

    def clear_cache # rubocop:disable Naming/PredicateMethod
      false
    end

    def enabled?
      false
    end

    def stats
      { backend: 'disabled', enabled: false }
    end

    # Entity-specific cache methods for compatibility with CacheManager interface
    def get_entity_data(_entity)
      nil
    end

    def set_entity_data(_entity, _data, is_secret: false) # rubocop:disable Lint/UnusedMethodArgument
      false
    end

    def purge_entity(_entity)
      false
    end
    # rubocop:enable Naming/PredicateMethod
  end
end
