# `Raxol.Terminal.ANSI.SixelPalette`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sixel_palette.ex#L1)

Handles Sixel color palette management.

Provides functions to initialize the default palette and potentially
manage custom color definitions in the future.

# `convert_color`

```elixir
@spec convert_color(integer(), integer(), integer(), integer()) ::
  {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
  | {:error, atom()}
```

Converts color parameters based on the specified color space.

Handles clamping values and delegation to specific conversion functions.
Supports HLS (1) and RGB (2).

# `define_color`

```elixir
@spec define_color(map(), non_neg_integer(), 1..2, 0..100, 0..100, 0..100) ::
  {:ok, map()} | {:error, atom()}
```

Defines a custom color in the palette using the Sixel "#" command format.

## Parameters
  * `palette` - The current color palette map
  * `index` - The color index to define (0-255)
  * `format` - The color space format (1 for HLS, 2 for RGB)
  * `p1` - First parameter (H or R)
  * `p2` - Second parameter (L or G)
  * `p3` - Third parameter (S or B)

## Returns
  * `{:ok, updated_palette}` - The updated palette with the new color
  * `{:error, reason}` - If the color definition fails

# `hls_to_rgb`

```elixir
@spec hls_to_rgb(float(), float(), float()) ::
  {:ok, {non_neg_integer(), non_neg_integer(), non_neg_integer()}}
```

Simplified HLS to RGB conversion (based on standard formulas).

Input: H (0-360), L (0-1), S (0-1)
Output: {:ok, {R, G, B}} (0-255)

# `initialize_palette`

```elixir
@spec initialize_palette() :: map()
```

Initializes the default Sixel color palette (256 colors).

# `max_colors`

```elixir
@spec max_colors() :: 255
```

Returns the maximum valid color index (typically 255 for a 256-color palette).

# `nearest_color`

```elixir
@spec nearest_color(
  {integer(), integer(), integer()},
  [{non_neg_integer(), {integer(), integer(), integer()}}]
) :: {non_neg_integer(), {integer(), integer(), integer()}}
```

Finds the palette entry closest to the given RGB color by Euclidean distance.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
