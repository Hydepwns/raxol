# `Raxol.Terminal.ImageCache`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/image_cache.ex#L1)

ETS-backed cache for decoded and encoded terminal images.

Caches expensive operations:
- PNG decode results (raw pixel data)
- Sixel/Kitty encoded output for given parameters

Keys are `{content_hash, opts_hash}` tuples. Entries expire after a
configurable TTL (default 5 minutes). The cache is created lazily on
first access and owned by the calling process (or an explicit owner).

## Usage

    ImageCache.start()
    ImageCache.put("img.png", png_bytes, %{max_colors: 64})
    {:ok, cached} = ImageCache.get("img.png", %{max_colors: 64})
    ImageCache.evict("img.png")

# `cache_entry`

```elixir
@type cache_entry() :: {cache_key(), term(), integer()}
```

# `cache_key`

```elixir
@type cache_key() :: {binary(), binary()}
```

# `clear`

```elixir
@spec clear() :: :ok
```

Deletes all entries from the cache.

# `evict`

```elixir
@spec evict(binary()) :: :ok
```

Removes all entries matching a source identifier (any opts).

# `fetch`

```elixir
@spec fetch(binary(), map(), (-&gt; {:ok, term()} | {:error, term()})) ::
  {:ok, term()} | {:error, term()}
```

Fetches from cache or computes and caches the value.

The `compute_fn` is called only on cache miss and must return
`{:ok, value}` or `{:error, reason}`.

# `get`

```elixir
@spec get(binary(), map()) :: {:ok, term()} | :miss
```

Retrieves a cached value. Returns `{:ok, value}` or `:miss`.
Expired entries are transparently deleted.

# `prune`

```elixir
@spec prune() :: non_neg_integer()
```

Removes all expired entries from the cache.

# `put`

```elixir
@spec put(binary(), term(), map()) :: :ok
```

Stores a value in the cache keyed by source identifier and options.

# `size`

```elixir
@spec size() :: non_neg_integer()
```

Returns the number of entries currently in the cache.

# `start`

```elixir
@spec start() :: :ok
```

Creates the ETS table if it doesn't already exist.
Safe to call multiple times.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
