# `Raxol.Terminal.Buffer.LineOperations.CharOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/buffer/line_operations/char_operations.ex#L1)

Character-level operations for buffer lines.
Handles character insertion, deletion, and manipulation within lines.

# `delete_chars`

```elixir
@spec delete_chars(list(), integer()) :: list()
@spec delete_chars(map(), integer()) :: map()
```

Delete characters from a line or buffer.

# `delete_chars_at`

```elixir
@spec delete_chars_at(map(), integer(), integer(), integer()) :: map()
```

Delete characters at a specific position in a buffer.

# `erase_chars`

```elixir
@spec erase_chars(map(), integer(), integer(), integer()) :: map()
```

Erase characters with a specific style.

# `insert_chars`

```elixir
@spec insert_chars(list(), list()) :: list()
@spec insert_chars(map(), integer()) :: map()
```

Insert characters into a line or insert blank characters at cursor position in buffer.

# `insert_chars_at`

```elixir
@spec insert_chars_at(map(), integer(), integer(), list()) :: map()
```

Insert characters at a specific position in a buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
