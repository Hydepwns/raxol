# `Raxol.Terminal.Modes.Types.ModeTypes`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/modes/types/mode_types.ex#L1)

Defines types and constants for terminal modes.
Provides a centralized registry of all terminal modes and their properties.

# `mode`

```elixir
@type mode() :: %{
  category: mode_category(),
  code: integer(),
  name: atom(),
  default_value: mode_value(),
  dependencies: [mode()],
  conflicts: [mode()]
}
```

# `mode_category`

```elixir
@type mode_category() :: :dec_private | :standard | :mouse | :screen_buffer
```

# `mode_state`

```elixir
@type mode_state() :: :enabled | :disabled | :unknown
```

# `mode_value`

```elixir
@type mode_value() :: boolean() | atom() | integer()
```

# `get_all_modes`

```elixir
@spec get_all_modes() :: %{required(integer()) =&gt; mode()}
```

Returns all registered modes.

# `get_modes_by_category`

```elixir
@spec get_modes_by_category(mode_category()) :: [mode()]
```

Returns all modes of a specific category.

# `lookup_private`

```elixir
@spec lookup_private(integer()) :: mode() | nil
```

Looks up a DEC private mode code and returns the corresponding mode definition.

# `lookup_standard`

```elixir
@spec lookup_standard(integer()) :: mode() | nil
```

Looks up a standard mode code and returns the corresponding mode definition.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
