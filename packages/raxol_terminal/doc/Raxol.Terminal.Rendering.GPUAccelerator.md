# `Raxol.Terminal.Rendering.GPUAccelerator`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/gpu_accelerator.ex#L1)

GPU-accelerated rendering backend for Raxol terminals using Metal (macOS) and Vulkan.

This module provides high-performance GPU-accelerated terminal rendering with:
- Metal API integration for macOS (optimal performance on Apple Silicon)
- Vulkan API support for cross-platform GPU acceleration
- Compute shaders for text rendering and effects
- Hardware-accelerated glyph rasterization
- GPU-based scrolling and animation
- Memory-efficient texture atlases for fonts
- Parallel rendering pipelines
- Adaptive quality scaling based on performance

## Features

### Performance Optimizations
- GPU-based glyph rendering with subpixel precision
- Texture atlas caching for font glyphs
- Instanced rendering for repeated characters
- Compute shader-based text layout
- Hardware scrolling without CPU intervention
- Parallel processing of multiple terminal sessions

### Visual Enhancements
- Hardware anti-aliasing (MSAA/FXAA)
- GPU-based text effects (shadows, outlines, glows)
- Real-time blur and transparency effects
- Smooth animations with GPU interpolation
- High-DPI rendering with pixel-perfect scaling
- Color space management and HDR support

## Usage

    # Initialize GPU acceleration
    {:ok, context} = GPUAccelerator.init(backend: :metal)

    # Create rendering surface
    surface = GPUAccelerator.create_surface(context, width: 1920, height: 1080)

    # Render terminal content
    terminal_buffer = get_terminal_buffer()
    GPUAccelerator.render(context, surface, terminal_buffer)

    # Enable effects
    GPUAccelerator.enable_effect(context, :blur, intensity: 0.5)
    GPUAccelerator.enable_effect(context, :glow, color: {0, 255, 128})

# `backend_type`

```elixir
@type backend_type() :: :metal | :vulkan | :auto
```

# `config`

```elixir
@type config() :: %{
  backend: backend_type(),
  vsync: boolean(),
  msaa_samples: 1 | 2 | 4 | 8 | 16,
  max_texture_size: integer(),
  enable_compute_shaders: boolean(),
  debug_mode: boolean(),
  performance_profile: :battery | :balanced | :performance
}
```

# `gpu_device`

```elixir
@type gpu_device() :: term()
```

# `render_stats`

```elixir
@type render_stats() :: %{
  frames_rendered: integer(),
  average_frame_time: float(),
  gpu_memory_usage: integer(),
  cache_hit_rate: float()
}
```

# `render_surface`

```elixir
@type render_surface() :: term()
```

# `shader_program`

```elixir
@type shader_program() :: term()
```

# `texture_atlas`

```elixir
@type texture_atlas() :: term()
```

# `available?`

Checks if GPU acceleration is available on the current system.

# `capabilities`

Gets the backend's capabilities and supported features.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `create_font_atlas`

Creates and manages a GPU texture atlas for font glyphs.

# `create_surface`

Creates a rendering surface for the specified dimensions.

# `destroy_surface`

Destroys a rendering surface and releases its resources.

# `disable_effect`

Disables a visual effect.

# `enable_effect`

Enables a visual effect on the rendering context.

# `get_stats`

Gets rendering performance statistics.

# `handle_manager_cast`

# `handle_manager_info`

# `initialize`

Initializes GPU acceleration with the specified configuration.

# `profile_performance`

Profiles GPU performance and suggests optimizations.

# `render`

Renders terminal content to the specified surface.

# `start_link`

# `update_config`

Updates the GPU acceleration configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
