# `Raxol.Terminal.Driver.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/driver/behaviour.ex#L1)

Behaviour specification for terminal drivers.

This behaviour defines the contract that terminal drivers must implement
to provide terminal I/O functionality. Different implementations can
provide native (NIF-based), pure Elixir, or web-based terminal support.

## Implementations

- `Raxol.Terminal.Driver` - Main driver with automatic backend selection
- `Raxol.Terminal.IOTerminal` - Pure Elixir implementation

## Example Implementation

    defmodule MyTerminalDriver do
      @behaviour Raxol.Terminal.Driver.Behaviour

      @impl true
      def init(opts) do
        # Initialize terminal
        {:ok, %{}}
      end

      @impl true
      def shutdown(state) do
        # Cleanup
        :ok
      end

      # ... implement other callbacks
    end

# `attributes`

```elixir
@type attributes() :: %{
  optional(:fg) =&gt; color(),
  optional(:bg) =&gt; color(),
  optional(:bold) =&gt; boolean(),
  optional(:italic) =&gt; boolean(),
  optional(:underline) =&gt; boolean(),
  optional(:reverse) =&gt; boolean(),
  optional(:blink) =&gt; boolean()
}
```

Cell attributes

# `color`

```elixir
@type color() :: atom() | non_neg_integer() | {r :: 0..255, g :: 0..255, b :: 0..255}
```

Color specification

# `dimensions`

```elixir
@type dimensions() :: {width :: pos_integer(), height :: pos_integer()}
```

Terminal dimensions

# `event`

```elixir
@type event() ::
  {:key, key_data :: map()}
  | {:mouse, mouse_data :: map()}
  | {:resize, width :: pos_integer(), height :: pos_integer()}
  | {:paste, content :: String.t()}
```

Terminal event

# `state`

```elixir
@type state() :: term()
```

Driver state - implementation specific

# `clear`

```elixir
@callback clear(state()) :: {:ok, state()} | {:error, term()}
```

Clear the entire screen.

# `clear_line`

```elixir
@callback clear_line(state()) :: {:ok, state()} | {:error, term()}
```

Clear from cursor to end of line.

# `flush`

```elixir
@callback flush(state()) :: {:ok, state()} | {:error, term()}
```

Flush any buffered output to the terminal.

# `get_cursor_position`

```elixir
@callback get_cursor_position(state()) ::
  {:ok, {x :: non_neg_integer(), y :: non_neg_integer()}} | {:error, term()}
```

Get the current cursor position.

# `get_size`

```elixir
@callback get_size(state()) :: {:ok, dimensions()} | {:error, term()}
```

Get the current terminal dimensions.

Returns the width and height in character cells.

# `init`

```elixir
@callback init(opts :: keyword()) :: {:ok, state()} | {:error, term()}
```

Initialize the terminal driver.

Called when the driver process starts. Should set up the terminal
for raw input mode and prepare for rendering.

## Options

Implementation-specific options may include:
- `:width` - Initial width (for testing)
- `:height` - Initial height (for testing)
- `:output_device` - Output device (default: :stdio)

## Returns

- `{:ok, state}` - Initialization successful
- `{:error, reason}` - Initialization failed

# `move_cursor`

```elixir
@callback move_cursor(state(), x :: non_neg_integer(), y :: non_neg_integer()) ::
  {:ok, state()} | {:error, term()}
```

Move the cursor to the specified position.

Coordinates are 0-indexed, with (0, 0) at the top-left corner.

# `poll_event`

```elixir
@callback poll_event(state(), timeout :: non_neg_integer()) ::
  {:ok, event(), state()} | {:timeout, state()} | {:error, term()}
```

Poll for input events.

Returns the next available event or `:timeout` if no event is available
within the specified timeout (in milliseconds).

# `reset_style`

```elixir
@callback reset_style(state()) :: {:ok, state()} | {:error, term()}
```

Reset all styling to defaults.

# `set_attributes`

```elixir
@callback set_attributes(state(), attributes()) :: {:ok, state()} | {:error, term()}
```

Set text attributes for subsequent output.

# `set_background`

```elixir
@callback set_background(state(), color()) :: {:ok, state()} | {:error, term()}
```

Set the background color for subsequent output.

# `set_bracketed_paste`
*optional* 

```elixir
@callback set_bracketed_paste(state(), enabled :: boolean()) ::
  {:ok, state()} | {:error, term()}
```

Enable or disable bracketed paste mode.

This is an optional callback - implementations may return `{:ok, state}`
without taking action if not supported.

# `set_cursor_visible`

```elixir
@callback set_cursor_visible(state(), visible :: boolean()) ::
  {:ok, state()} | {:error, term()}
```

Show or hide the cursor.

# `set_foreground`

```elixir
@callback set_foreground(state(), color()) :: {:ok, state()} | {:error, term()}
```

Set the foreground color for subsequent output.

# `set_mouse_enabled`
*optional* 

```elixir
@callback set_mouse_enabled(state(), enabled :: boolean()) ::
  {:ok, state()} | {:error, term()}
```

Enable or disable mouse input.

This is an optional callback - implementations may return `{:ok, state}`
without taking action if not supported.

# `set_title`
*optional* 

```elixir
@callback set_title(state(), title :: String.t()) :: {:ok, state()} | {:error, term()}
```

Set the terminal title.

This is an optional callback - implementations may return `{:ok, state}`
without taking action if not supported.

# `shutdown`

```elixir
@callback shutdown(state()) :: :ok
```

Shut down the terminal driver.

Called when the driver process terminates. Should restore the terminal
to its original state.

# `write`

```elixir
@callback write(state(), content :: String.t()) :: {:ok, state()} | {:error, term()}
```

Write a string at the current cursor position.

# `write_at`

```elixir
@callback write_at(
  state(),
  x :: non_neg_integer(),
  y :: non_neg_integer(),
  content :: String.t(),
  attrs :: attributes()
) :: {:ok, state()} | {:error, term()}
```

Write a string at the specified position with optional attributes.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
