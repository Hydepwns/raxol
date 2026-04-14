# `Raxol.Terminal.OutputBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/output_buffer.ex#L1)

Simple output buffer implementation for terminal output.

# `t`

```elixir
@type t() :: String.t()
```

# `clear`

```elixir
@spec clear(t()) :: t()
```

Clears the output buffer.

# `empty?`

```elixir
@spec empty?(t()) :: boolean()
```

Checks if the output buffer is empty.

# `flush`

```elixir
@spec flush(t()) :: {:ok, t()}
```

Flushes the output buffer.

# `get_content`

```elixir
@spec get_content(t()) :: String.t()
```

Gets the current output buffer content.

# `get_encoding`

```elixir
@spec get_encoding(t()) :: String.t()
```

Gets the current output buffer encoding.

# `get_mode`

```elixir
@spec get_mode(t()) :: atom()
```

Gets the current output buffer mode.

# `get_size`

```elixir
@spec get_size(t()) :: non_neg_integer()
```

Gets the output buffer size.

# `set_content`

```elixir
@spec set_content(t(), String.t()) :: t()
```

Sets the output buffer content.

# `set_encoding`

```elixir
@spec set_encoding(t(), String.t()) :: t()
```

Sets the output buffer encoding.

# `set_mode`

```elixir
@spec set_mode(t(), atom()) :: t()
```

Sets the output buffer mode.

# `write`

```elixir
@spec write(t(), String.t()) :: t()
```

Writes a string to the output buffer.

# `writeln`

```elixir
@spec writeln(t(), String.t()) :: t()
```

Writes a string to the output buffer with a newline.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
