# `Raxol.Core.Utils.List`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/utils/list.ex#L1)

Shared list and collection utilities.

# `ensure_list`

```elixir
@spec ensure_list(list()) :: list()
@spec ensure_list(term()) :: [term()]
```

Wraps a non-list value in a list. Returns lists unchanged.

## Examples

    iex> Raxol.Core.Utils.List.ensure_list([1, 2])
    [1, 2]

    iex> Raxol.Core.Utils.List.ensure_list(:foo)
    [:foo]

# `zip_longest`

```elixir
@spec zip_longest(list(), list()) :: [{term(), term()}]
```

Zips two lists, padding the shorter one with `nil`.

Unlike `Enum.zip/2`, this does not truncate to the shorter list.

## Examples

    iex> Raxol.Core.Utils.List.zip_longest([1, 2, 3], [:a, :b])
    [{1, :a}, {2, :b}, {3, nil}]

    iex> Raxol.Core.Utils.List.zip_longest([1], [2, 3])
    [{1, 2}, {nil, 3}]

---

*Consult [api-reference.md](api-reference.md) for complete listing*
