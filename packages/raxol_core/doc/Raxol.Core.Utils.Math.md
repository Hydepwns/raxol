# `Raxol.Core.Utils.Math`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/math.ex#L1)

Shared numeric utilities.

# `clamp`

```elixir
@spec clamp(number(), number(), number()) :: number()
```

Clamps `value` to the range `[lo, hi]`.

## Examples

    iex> Raxol.Core.Utils.Math.clamp(5, 0, 10)
    5

    iex> Raxol.Core.Utils.Math.clamp(-1, 0, 10)
    0

    iex> Raxol.Core.Utils.Math.clamp(15, 0, 10)
    10

# `scroll_into_view`

```elixir
@spec scroll_into_view(integer(), integer(), pos_integer()) :: integer()
```

Computes the scroll offset needed to keep `index` visible in a viewport
of `visible_count` items starting at `scroll_offset`.

Returns the (possibly adjusted) scroll offset.

## Examples

    iex> Raxol.Core.Utils.Math.scroll_into_view(5, 0, 10)
    0

    iex> Raxol.Core.Utils.Math.scroll_into_view(12, 0, 10)
    3

    iex> Raxol.Core.Utils.Math.scroll_into_view(2, 5, 10)
    2

---

*Consult [api-reference.md](api-reference.md) for complete listing*
