# `Raxol.Terminal.ANSI.SixelGraphics`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sixel_graphics.ex#L1)

Complete Sixel graphics support for terminal rendering.

This module provides comprehensive Sixel (DEC Sixel Graphics) support:
* Full Sixel image encoding and decoding
* Advanced color palette management with quantization
* Image format conversion (PNG, JPEG, GIF -> Sixel)
* Color optimization and dithering algorithms
* Animation frame support
* Terminal compatibility detection
* Performance optimizations for large images

## Sixel Format

Sixel is a bitmap graphics format developed by Digital Equipment Corporation
for their terminals. Each character represents 6 vertical pixels, allowing
efficient transmission of images over serial connections.

## Features

- PNG/JPEG/GIF to Sixel conversion
- Color palette optimization (up to 256 colors)
- Floyd-Steinberg dithering
- Transparency support
- Animation support for GIF files
- Compression and size optimization

# `color_format`

```elixir
@type color_format() :: :rgb | :rgba | :hsl | :indexed
```

# `dithering_algorithm`

```elixir
@type dithering_algorithm() :: :none | :floyd_steinberg | :ordered | :random
```

# `image_format`

```elixir
@type image_format() :: :png | :jpeg | :gif | :bmp | :raw_rgb | :raw_rgba
```

# `rgb_color`

```elixir
@type rgb_color() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

# `rgba_color`

```elixir
@type rgba_color() ::
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

# `sixel_options`

```elixir
@type sixel_options() :: %{
  optional(:max_colors) =&gt; non_neg_integer(),
  optional(:dithering) =&gt; dithering_algorithm(),
  optional(:transparent_color) =&gt; rgb_color() | nil,
  optional(:optimize_palette) =&gt; boolean(),
  optional(:target_width) =&gt; non_neg_integer() | nil,
  optional(:target_height) =&gt; non_neg_integer() | nil,
  optional(:preserve_aspect_ratio) =&gt; boolean()
}
```

# `sixel_state`

```elixir
@type sixel_state() :: %{
  width: non_neg_integer(),
  height: non_neg_integer(),
  data: binary(),
  palette: map(),
  current_color: non_neg_integer(),
  pixel_buffer: map()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.SixelGraphics{
  animation_frames: [t()] | nil,
  attributes: map(),
  compression_enabled: boolean(),
  current_color: non_neg_integer(),
  data: binary(),
  dithering_algorithm: dithering_algorithm(),
  height: non_neg_integer(),
  original_format: image_format() | nil,
  palette: map(),
  pixel_buffer: map(),
  position: {non_neg_integer(), non_neg_integer()},
  scale: {non_neg_integer(), non_neg_integer()},
  sixel_cursor_pos: {non_neg_integer(), non_neg_integer()},
  transparent_color: rgb_color() | nil,
  width: non_neg_integer()
}
```

# `apply_dithering`

```elixir
@spec apply_dithering(t(), dithering_algorithm()) :: t()
```

Applies dithering to reduce color banding when quantizing colors.

Delegates to `Raxol.Terminal.ANSI.SixelDithering` which implements
Floyd-Steinberg error diffusion, ordered (Bayer 4x4), and random noise.

## Parameters

* `image` - The Sixel image (must have pixel_buffer and palette)
* `algorithm` - Dithering algorithm (:floyd_steinberg, :ordered, :random, :none)

## Returns

* `t()` - Image with dithering applied to pixel_buffer

# `decode`

```elixir
@spec decode(binary()) :: t()
```

Decodes an ANSI escape sequence into a Sixel image.

## Parameters

* `data` - The ANSI escape sequence to decode

## Returns

A new `t:Raxol.Terminal.ANSI.SixelGraphics.t/0` struct with the decoded image data.

# `encode`

```elixir
@spec encode(t()) :: binary()
```

Encodes a Sixel image to ANSI escape sequence.

## Parameters

* `image` - The image to encode

## Returns

A binary containing the ANSI escape sequence for the Sixel image.

# `from_image_data`

```elixir
@spec from_image_data(binary(), :png | :jpeg | :gif | atom(), sixel_options()) ::
  {:ok, t()} | {:error, term()}
```

Converts an image from common formats (PNG, JPEG, GIF) to Sixel format.

## Parameters

* `image_data` - Binary image data
* `format` - Image format (:png, :jpeg, :gif)
* `options` - Sixel conversion options

## Returns

* `{:ok, sixel_image}` - Converted Sixel image
* `{:error, reason}` - Conversion error

# `get_data`

```elixir
@spec get_data(t()) :: binary()
```

Gets the current image data.

## Parameters

* `image` - The current image

## Returns

The binary image data.

# `get_palette`

```elixir
@spec get_palette(t()) :: map()
```

Gets the current color palette.

## Parameters

* `image` - The current image

## Returns

A map containing the current color palette.

# `get_position`

```elixir
@spec get_position(t()) :: {non_neg_integer(), non_neg_integer()}
```

Gets the current position.

## Parameters

* `image` - The current image

## Returns

A tuple `{x, y}` with the current position.

# `get_scale`

```elixir
@spec get_scale(t()) :: {non_neg_integer(), non_neg_integer()}
```

Gets the current scale factors.

## Parameters

* `image` - The current image

## Returns

A tuple `{x_scale, y_scale}` with the current scale factors.

# `new`

```elixir
@spec new() :: t()
```

Creates a new Sixel image with default values.

## Returns

A new `t:Raxol.Terminal.ANSI.SixelGraphics.t/0` struct with default values.

# `new`

```elixir
@spec new(pos_integer(), pos_integer()) :: t()
```

Creates a new Sixel image with specified dimensions.

## Parameters

* `width` - The image width in pixels
* `height` - The image height in pixels

## Returns

A new `t:Raxol.Terminal.ANSI.SixelGraphics.t/0` struct with the specified dimensions.

# `optimize_palette`

```elixir
@spec optimize_palette(t(), pos_integer(), :median_cut | :octree) :: t()
```

Optimizes the color palette using quantization algorithms.

## Parameters

* `image` - The Sixel image
* `max_colors` - Maximum number of colors (default: 256)
* `algorithm` - Quantization algorithm (:median_cut, :octree)

## Returns

* `t()` - Image with optimized palette

# `process_sequence`

```elixir
@spec process_sequence(t(), binary()) :: {t(), :ok | {:error, term()}}
```

Processes a sequence of Sixel data.

## Parameters

* `state` - The current Sixel state
* `data` - The Sixel data to process

## Returns

A tuple containing the updated state and a response.

# `set_data`

```elixir
@spec set_data(t(), binary()) :: t()
```

Sets the image data for a Sixel image.

## Parameters

* `image` - The current image
* `data` - The binary image data

## Returns

The updated image with new data.

# `set_palette`

```elixir
@spec set_palette(t(), map()) :: t()
```

Sets the color palette for a Sixel image.

## Parameters

* `image` - The current image
* `palette` - A map of color indices to RGB values

## Returns

The updated image with new palette.

# `set_position`

```elixir
@spec set_position(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Sets the position for a Sixel image.

## Parameters

* `image` - The current image
* `x` - The horizontal position
* `y` - The vertical position

## Returns

The updated image with new position.

# `set_scale`

```elixir
@spec set_scale(t(), pos_integer(), pos_integer()) :: t()
```

Sets the scale factor for a Sixel image.

## Parameters

* `image` - The current image
* `x_scale` - The horizontal scale factor
* `y_scale` - The vertical scale factor

## Returns

The updated image with new scale factors.

# `supported?`

```elixir
@spec supported?() :: boolean()
```

Checks if the terminal supports Sixel graphics.

## Returns

`true` if Sixel graphics are supported, `false` otherwise.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
