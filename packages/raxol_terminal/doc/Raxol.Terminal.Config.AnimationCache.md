# `Raxol.Terminal.Config.AnimationCache`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/animation_cache.ex#L1)

Manages caching for terminal animations using the unified caching system.

# `cache_animation`

Caches an animation from a file.

## Parameters
  * `animation_path` - Path to the animation file
  * `animation_type` - Type of animation (:gif, :video, :shader, :particle)

# `cache_animation_data`

Caches animation data directly (for testing and in-memory usage).

## Parameters
  * `animation_key` - Key to store the animation under
  * `animation_data` - Animation data to cache

# `clear_animation_cache`

Clears the animation cache.

# `decompress_animation`

Decompresses an animation.

## Parameters
  * `compressed_data` - Compressed animation data

# `get_animation_cache_stats`

Gets animation cache statistics.

# `get_cache_size`

Gets the current cache size.

# `get_cached_animation`

Gets a cached animation.

## Parameters
  * `animation_path` - Path to the animation file

# `init_animation_cache`

Initializes the animation cache.

# `preload_animation`

Preloads a single animation.

## Parameters
  * `animation_path` - Path to the animation file

# `preload_animations`

Preloads animations from the preload directory.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
