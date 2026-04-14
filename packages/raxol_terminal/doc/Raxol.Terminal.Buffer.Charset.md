# `Raxol.Terminal.Buffer.Charset`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/charset.ex#L1)

Manages character set state and operations for the screen buffer.
This module handles character set designations, G-sets, and single shifts.

# `charset_type`

```elixir
@type charset_type() :: :us_ascii | :dec_graphics | :uk | :ibm_pc | :dec_alternate
```

# `designator`

```elixir
@type designator() :: :g0 | :g1 | :g2 | :g3
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.Charset{
  g0: charset_type(),
  g1: charset_type(),
  g2: charset_type(),
  g3: charset_type(),
  gl: designator(),
  gr: designator(),
  single_shift: designator() | nil
}
```

# `apply_single_shift`

Applies a single shift to a specific G-set.

## Parameters

* `buffer` - The screen buffer to modify
* `slot` - The G-set to shift to (:g0, :g1, :g2, or :g3)

## Returns

The updated screen buffer with new single shift.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Charset.apply_single_shift(buffer, :g1)
    iex> Charset.get_single_shift(buffer)
    :g1

# `designate`

Designates a character set to a specific slot.

## Parameters

* `buffer` - The screen buffer to modify
* `slot` - The slot to designate (:g0, :g1, :g2, or :g3)
* `charset` - The character set to designate

## Returns

The updated screen buffer with new charset designation.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Charset.designate(buffer, :g0, :us_ascii)
    iex> Charset.get_designated(buffer, :g0)
    :us_ascii

# `get_current_g_set`

Gets the current G-set.

## Parameters

* `buffer` - The screen buffer to query

## Returns

The current G-set.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Charset.get_current_g_set(buffer)
    :g0

# `get_designated`

Gets the designated character set for a specific slot.

## Parameters

* `buffer` - The screen buffer to query
* `slot` - The slot to query (:g0, :g1, :g2, or :g3)

## Returns

The designated character set for the slot.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Charset.get_designated(buffer, :g0)
    :us_ascii

# `get_single_shift`

Gets the current single shift.

## Parameters

* `buffer` - The screen buffer to query

## Returns

The current single shift or nil if none is active.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Charset.get_single_shift(buffer)
    nil

# `init`

Initializes a new charset state with default values.

# `invoke_g_set`

Invokes a G-set for the left or right side.

## Parameters

* `buffer` - The screen buffer to modify
* `slot` - The G-set to invoke (:g0, :g1, :g2, or :g3)

## Returns

The updated screen buffer with new G-set invocation.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Charset.invoke_g_set(buffer, :g1)
    iex> Charset.get_current_g_set(buffer)
    :g1

# `reset`

Resets the charset state to default values.

## Parameters

* `buffer` - The screen buffer to modify

## Returns

The updated screen buffer with reset charset state.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> buffer = Charset.reset(buffer)
    iex> Charset.get_current_g_set(buffer)
    :g0

# `translate_char`

Translates a character according to the current charset state.

## Parameters

* `buffer` - The screen buffer to use for translation
* `char` - The character to translate

## Returns

The translated character.

## Examples

    iex> buffer = ScreenBuffer.new(80, 24)
    iex> Charset.translate_char(buffer, "A")
    "A"

---

*Consult [api-reference.md](api-reference.md) for complete listing*
