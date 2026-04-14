# `Raxol.Terminal.Output.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/output/output_manager.ex#L1)

Manages terminal output buffering, event processing, styling, and formatting.
This module handles output events, applies styles and formatting rules, and tracks metrics.

# `buffer`

```elixir
@type buffer() :: %{events: [event()], max_size: non_neg_integer()}
```

# `event`

```elixir
@type event() :: %{
  content: String.t(),
  style: String.t(),
  timestamp: integer(),
  priority: integer()
}
```

# `format_rule`

```elixir
@type format_rule() :: (String.t() -&gt; String.t())
```

# `metrics`

```elixir
@type metrics() :: %{
  processed_events: non_neg_integer(),
  batch_count: non_neg_integer(),
  format_applications: non_neg_integer(),
  style_applications: non_neg_integer()
}
```

# `style`

```elixir
@type style() :: %{
  foreground: String.t() | nil,
  background: String.t() | nil,
  bold: boolean(),
  italic: boolean(),
  underline: boolean()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Output.Manager{
  batch_size: pos_integer(),
  buffer: buffer(),
  format_rules: [format_rule()],
  metrics: metrics(),
  style_map: %{required(String.t()) =&gt; style()}
}
```

# `add_format_rule`

```elixir
@spec add_format_rule(t(), format_rule()) :: t()
```

Adds a custom formatting rule.
Returns the updated manager.

# `add_style`

```elixir
@spec add_style(t(), String.t(), style()) :: t()
```

Adds a custom style to the style map.
Returns the updated manager.

# `flush_buffer`

```elixir
@spec flush_buffer(t()) :: t()
```

Flushes the output buffer.
Returns the updated manager with an empty buffer.

# `get_metrics`

```elixir
@spec get_metrics(t()) :: metrics()
```

Gets the current metrics.

# `new`

```elixir
@spec new(keyword()) :: t()
```

Creates a new output manager instance.

# `process_batch`

```elixir
@spec process_batch(t(), [event()]) :: {:ok, t()} | {:error, :invalid_event}
```

Processes a batch of output events.
Returns {:ok, updated_manager} or {:error, :invalid_event}.

# `process_output`

```elixir
@spec process_output(t(), event()) :: {:ok, t()} | {:error, :invalid_event}
```

Processes a single output event.
Returns {:ok, updated_manager} or {:error, :invalid_event}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
