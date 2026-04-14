# `Raxol.Terminal.Rendering.Backend`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/backend.ex#L1)

Behaviour definition for terminal rendering backends.

This module defines the interface that all rendering backends must implement,
including GPU-accelerated backends (OpenGL, Metal, Vulkan) and software rendering.

# `effect_type`

```elixir
@type effect_type() :: :blur | :glow | :scanlines | :chromatic_aberration | :vignette
```

# `render_opts`

```elixir
@type render_opts() :: [
  viewport: {integer(), integer(), pos_integer(), pos_integer()},
  scale: float(),
  vsync: boolean(),
  effects: list()
]
```

# `stats`

```elixir
@type stats() :: %{
  fps: float(),
  frame_time: float(),
  draw_calls: non_neg_integer(),
  vertices: non_neg_integer(),
  memory_usage: non_neg_integer()
}
```

# `surface`

```elixir
@type surface() :: %{
  id: String.t(),
  width: pos_integer(),
  height: pos_integer(),
  format: atom(),
  backend: atom()
}
```

# `terminal_buffer`

```elixir
@type terminal_buffer() :: %{
  lines: list(),
  width: pos_integer(),
  height: pos_integer(),
  cursor: map(),
  colors: map()
}
```

# `available?`

```elixir
@callback available?() :: boolean()
```

Checks if the backend is available on the current system.

# `capabilities`

```elixir
@callback capabilities() :: %{
  max_texture_size: pos_integer(),
  supports_shaders: boolean(),
  supports_effects: [effect_type()],
  hardware_accelerated: boolean()
}
```

Gets the backend's capabilities and supported features.

# `create_surface`

```elixir
@callback create_surface(state :: term(), opts :: keyword()) ::
  {:ok, surface(), new_state :: term()} | {:error, reason :: term()}
```

Creates a rendering surface with the specified options.

# `destroy_surface`

```elixir
@callback destroy_surface(state :: term(), surface :: surface()) ::
  {:ok, new_state :: term()} | {:error, reason :: term()}
```

Destroys a rendering surface and releases its resources.

# `disable_effect`

```elixir
@callback disable_effect(state :: term(), effect :: effect_type()) ::
  {:ok, new_state :: term()} | {:error, reason :: term()}
```

Disables a visual effect.

# `enable_effect`

```elixir
@callback enable_effect(
  state :: term(),
  effect :: effect_type(),
  params :: keyword()
) :: {:ok, new_state :: term()} | {:error, reason :: term()}
```

Enables a visual effect on the rendering backend.

# `get_stats`

```elixir
@callback get_stats(state :: term()) :: {:ok, stats(), new_state :: term()}
```

Gets rendering performance statistics.

# `init`

```elixir
@callback init(config :: map()) :: {:ok, state :: term()} | {:error, reason :: term()}
```

Initializes the rendering backend with the given configuration.

# `render`

```elixir
@callback render(
  state :: term(),
  surface :: surface(),
  buffer :: terminal_buffer(),
  opts :: render_opts()
) :: {:ok, new_state :: term()} | {:error, reason :: term()}
```

Renders terminal content to the specified surface.

# `update_config`

```elixir
@callback update_config(state :: term(), config :: map()) ::
  {:ok, new_state :: term()} | {:error, reason :: term()}
```

Updates the backend configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
