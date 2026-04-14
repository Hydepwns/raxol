# `Raxol.Terminal.Cache.System`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/cache/system.ex#L1)

Unified caching system for the Raxol terminal emulator.
This module provides a centralized caching mechanism that consolidates all caching
operations across the terminal system, including:
- Buffer caching
- Animation caching
- Scroll caching
- Clipboard caching
- General purpose caching

# `cache_entry`

```elixir
@type cache_entry() :: %{
  value: cache_value(),
  size: non_neg_integer(),
  created_at: integer(),
  last_access: integer(),
  access_count: non_neg_integer(),
  ttl: integer() | nil,
  metadata: map()
}
```

# `cache_key`

```elixir
@type cache_key() :: term()
```

# `cache_stats`

```elixir
@type cache_stats() :: %{
  size: non_neg_integer(),
  max_size: non_neg_integer(),
  hit_count: non_neg_integer(),
  miss_count: non_neg_integer(),
  hit_ratio: float(),
  eviction_count: non_neg_integer()
}
```

# `cache_value`

```elixir
@type cache_value() :: term()
```

# `namespace`

```elixir
@type namespace() :: :buffer | :animation | :scroll | :clipboard | :general
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear`

Clears the cache.

## Parameters
  * `opts` - Clear options
    * `:namespace` - Cache namespace (default: :general)

# `get`

Gets a value from the cache.

## Parameters
  * `key` - The cache key
  * `opts` - Get options
    * `:namespace` - Cache namespace (default: :general)

# `handle_manager_cast`

# `handle_manager_info`

# `invalidate`

Invalidates a cache entry.

## Parameters
  * `key` - The cache key
  * `opts` - Invalidate options
    * `:namespace` - Cache namespace (default: :general)

# `monotonic_time`

```elixir
@spec monotonic_time() :: integer()
```

Returns the current monotonic time in milliseconds.
This is used for cache expiration and timing operations.

# `put`

Puts a value in the cache.

## Parameters
  * `key` - The cache key
  * `value` - The value to cache
  * `opts` - Put options
    * `:namespace` - Cache namespace (default: :general)
    * `:ttl` - Time-to-live in seconds
    * `:metadata` - Additional metadata

# `start_link`

# `stats`

Gets cache statistics.

## Parameters
  * `opts` - Stats options
    * `:namespace` - Cache namespace (default: :general)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
