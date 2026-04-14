# `Raxol.Terminal.Buffer.DamageTracker`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/damage_tracker.ex#L1)

Tracks damage regions in a terminal buffer for efficient rendering.
Damage regions indicate areas that have changed and need to be redrawn.

# `region`

```elixir
@type region() ::
  {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Buffer.DamageTracker{
  max_regions: non_neg_integer(),
  regions: [region()]
}
```

# `add_damage_region`

```elixir
@spec add_damage_region(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: t()
```

Adds a damage region to the tracker.

# `add_damage_regions`

```elixir
@spec add_damage_regions(t(), [region()]) :: t()
```

Adds multiple damage regions at once.

# `clear_damage`

```elixir
@spec clear_damage(t()) :: t()
```

Clears all damage regions.

# `damage_count`

```elixir
@spec damage_count(t()) :: non_neg_integer()
```

Returns the count of damage regions.

# `get_damage_regions`

```elixir
@spec get_damage_regions(t()) :: [region()]
```

Gets all damage regions.

# `has_damage?`

```elixir
@spec has_damage?(t()) :: boolean()
```

Checks if there are any damage regions.

# `merge_regions`

```elixir
@spec merge_regions(t()) :: t()
```

Merges overlapping or adjacent regions to reduce redundancy.

# `new`

```elixir
@spec new(non_neg_integer()) :: t()
```

Creates a new damage tracker with a maximum region limit.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
