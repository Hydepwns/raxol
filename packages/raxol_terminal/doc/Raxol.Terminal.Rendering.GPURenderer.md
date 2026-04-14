# `Raxol.Terminal.Rendering.GPURenderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/gpu_renderer.ex#L1)

GPU-accelerated terminal renderer.

This module provides hardware-accelerated rendering capabilities for the terminal,
utilizing the GPU for improved performance. It includes:
- Hardware-accelerated text rendering
- GPU-based buffer management
- Optimized render pipeline
- Performance monitoring and optimization

## Features

- GPU-accelerated text rendering
- Hardware-accelerated buffer management
- Efficient render pipeline
- Performance optimization
- Memory management
- Resource pooling

# `t`

```elixir
@type t() :: %Raxol.Terminal.Rendering.GPURenderer{
  buffer_pool: map(),
  gpu_context: map(),
  performance_metrics: map(),
  render_pipeline: map(),
  renderer: Raxol.Terminal.Renderer.t()
}
```

# `get_performance_metrics`

```elixir
@spec get_performance_metrics(t()) :: map()
```

Gets the current performance metrics.

## Parameters

* `gpu_renderer` - The GPU renderer instance

## Returns

Map containing performance metrics

# `new`

```elixir
@spec new(
  Raxol.Terminal.Renderer.t(),
  keyword()
) :: t()
```

# `optimize_pipeline`

```elixir
@spec optimize_pipeline(t()) :: t()
```

Optimizes the render pipeline based on current performance metrics.

## Parameters

* `gpu_renderer` - The GPU renderer instance

## Returns

Updated GPU renderer instance with optimized pipeline

# `render`

```elixir
@spec render(
  t(),
  keyword()
) :: {String.t(), t()}
```

Renders the screen buffer using GPU acceleration.

## Parameters

* `gpu_renderer` - The GPU renderer instance
* `opts` - Rendering options

## Returns

Tuple containing {output, updated_gpu_renderer}

# `update_pipeline`

```elixir
@spec update_pipeline(t(), map()) :: t()
```

Updates the render pipeline configuration.

## Parameters

* `gpu_renderer` - The GPU renderer instance
* `config` - The new pipeline configuration

## Returns

Updated GPU renderer instance

---

*Consult [api-reference.md](api-reference.md) for complete listing*
