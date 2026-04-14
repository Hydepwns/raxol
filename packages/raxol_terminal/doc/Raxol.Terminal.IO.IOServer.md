# `Raxol.Terminal.IO.IOServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/io/io_server.ex#L1)

Unified input/output system for the terminal emulator.

This module provides a consolidated interface for handling all terminal I/O operations,
including:
- Input event processing (keyboard, mouse, special keys)
- Output buffering and processing
- Command history management
- Input mode management
- Event propagation control
- Performance optimizations

# `completion_callback`

```elixir
@type completion_callback() :: (String.t() -&gt; [String.t()])
```

# `input_mode`

```elixir
@type input_mode() :: :normal | :insert | :replace | :command
```

# `mouse_button`

```elixir
@type mouse_button() :: 0 | 1 | 2 | 3 | 4
```

# `mouse_event`

```elixir
@type mouse_event() ::
  {mouse_event_type(), mouse_button(), non_neg_integer(), non_neg_integer()}
```

# `mouse_event_type`

```elixir
@type mouse_event_type() :: :press | :release | :move | :scroll
```

# `special_key`

```elixir
@type special_key() ::
  :up
  | :down
  | :left
  | :right
  | :home
  | :end
  | :page_up
  | :page_down
  | :insert
  | :delete
  | :escape
  | :tab
  | :enter
  | :backspace
  | :f1
  | :f2
  | :f3
  | :f4
  | :f5
  | :f6
  | :f7
  | :f8
  | :f9
  | :f10
  | :f11
  | :f12
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.IO.IOServer{
  buffer: String.t(),
  buffer_manager: pid() | nil,
  clipboard_content: String.t() | nil,
  clipboard_history: [String.t()],
  command_history: term(),
  completion_callback: completion_callback() | nil,
  completion_context: map() | nil,
  completion_index: non_neg_integer(),
  completion_options: [String.t()],
  config: map(),
  history_index: integer() | nil,
  input_history: [String.t()],
  input_queue: [String.t()],
  last_event_time: integer() | nil,
  last_input: String.t() | nil,
  mode: input_mode(),
  modifier_state: map(),
  mouse_buttons: MapSet.t(mouse_button()),
  mouse_enabled: boolean(),
  mouse_position: {non_neg_integer(), non_neg_integer()},
  output_buffer: String.t(),
  output_processing: boolean(),
  output_queue: [String.t()],
  processing_escape: boolean(),
  prompt: String.t() | nil,
  renderer: pid() | nil,
  scroll_buffer: Raxol.Terminal.Buffer.Scroll.t()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

Cleans up the I/O manager.

# `handle_manager_cast`

# `handle_manager_info`

# `init_terminal`

Initializes the terminal IO system.

# `process_input`

Processes an input event.

# `process_output`

Processes output data.

# `reset_config`

Resets the configuration to defaults.

# `resize`

Resizes the terminal.

# `set_config_value`

Sets a specific configuration value.

# `set_cursor_visibility`

Sets cursor visibility.

# `start_link`

# `update_config`

Updates the IO configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
