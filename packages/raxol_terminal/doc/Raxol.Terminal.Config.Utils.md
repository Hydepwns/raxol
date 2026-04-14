# `Raxol.Terminal.Config.Utils`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/config/utils.ex#L1)

Utility functions for handling terminal configuration maps.

# `deep_merge`

```elixir
@spec deep_merge(map(), map()) :: map()
```

Deeply merges two maps.

Keys in the right map take precedence. If both values for a key are maps,
they are merged recursively.

# `merge_opts`

```elixir
@spec merge_opts(map(), Keyword.t() | map()) :: map()
```

Merges configuration options into an existing configuration map.

The `opts` are first converted into a nested map structure and then
deeply merged into the `current_config`.

# `opts_to_nested_map`

```elixir
@spec opts_to_nested_map(Keyword.t() | map()) :: map()
```

Converts a keyword list or map of potentially nested options into a nested map.

Handles flat keys like `theme: "light"` and nested paths represented
by lists like `[behavior: [scrollback: 100]]` within the keyword list.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
