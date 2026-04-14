# `Raxol.Terminal.ScreenBufferBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/behaviour.ex#L1)

Defines the behaviour for screen buffer operations in the terminal.
This module specifies the callbacks that must be implemented by any module
that wants to act as a screen buffer.

# `charset`

```elixir
@type charset() :: atom()
```

# `color`

```elixir
@type color() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

# `dimensions`

```elixir
@type dimensions() :: {non_neg_integer(), non_neg_integer()}
```

# `metric`

```elixir
@type metric() :: atom()
```

# `metric_tags`

```elixir
@type metric_tags() :: map()
```

# `metric_value`

```elixir
@type metric_value() :: number()
```

# `position`

```elixir
@type position() :: {non_neg_integer(), non_neg_integer()}
```

# `style`

```elixir
@type style() :: map() | nil
```

# `t`

```elixir
@type t() :: term()
```

# `apply_single_shift`

```elixir
@callback apply_single_shift(buffer :: t(), slot :: atom() | integer()) :: t()
```

# `attribute_set?`

```elixir
@callback attribute_set?(buffer :: t(), attribute :: atom()) :: boolean()
```

# `cleanup_file_watching`

```elixir
@callback cleanup_file_watching(buffer :: t()) :: t()
```

# `clear_line`

```elixir
@callback clear_line(buffer :: t(), line :: non_neg_integer()) :: t()
```

# `clear_output_buffer`

```elixir
@callback clear_output_buffer(buffer :: t()) :: t()
```

# `clear_saved_states`

```elixir
@callback clear_saved_states(buffer :: t()) :: t()
```

# `clear_screen`

```elixir
@callback clear_screen(buffer :: t()) :: t()
```

# `clear_scroll_region`

```elixir
@callback clear_scroll_region(buffer :: t()) :: t()
```

# `collect_metrics`

```elixir
@callback collect_metrics(buffer :: t(), metrics :: [metric()]) :: map()
```

# `create_chart`

```elixir
@callback create_chart(buffer :: t(), data :: map(), options :: map()) :: t()
```

# `current_theme`

```elixir
@callback current_theme() :: map()
```

# `designate_charset`

```elixir
@callback designate_charset(
  buffer :: t(),
  slot :: atom() | integer(),
  charset :: charset()
) :: t()
```

# `empty?`

```elixir
@callback empty?(cell :: map()) :: boolean()
```

# `enqueue_control_sequence`

```elixir
@callback enqueue_control_sequence(buffer :: t(), sequence :: String.t()) :: t()
```

# `erase_all`

```elixir
@callback erase_all(buffer :: t()) :: t()
```

# `erase_all_with_scrollback`

```elixir
@callback erase_all_with_scrollback(buffer :: t()) :: t()
```

# `erase_from_cursor_to_end`

```elixir
@callback erase_from_cursor_to_end(buffer :: t()) :: t()
```

# `erase_from_cursor_to_end_of_line`

```elixir
@callback erase_from_cursor_to_end_of_line(buffer :: t()) :: t()
```

# `erase_from_start_of_line_to_cursor`

```elixir
@callback erase_from_start_of_line_to_cursor(buffer :: t()) :: t()
```

# `erase_from_start_to_cursor`

```elixir
@callback erase_from_start_to_cursor(buffer :: t()) :: t()
```

# `erase_line`

```elixir
@callback erase_line(buffer :: t()) :: t()
```

# `flush_output`

```elixir
@callback flush_output(buffer :: t()) :: t()
```

# `get_background`

```elixir
@callback get_background(buffer :: t()) :: color()
```

# `get_cell`

```elixir
@callback get_cell(
  buffer :: t(),
  x :: non_neg_integer(),
  y :: non_neg_integer()
) :: map()
```

# `get_char`

```elixir
@callback get_char(
  buffer :: t(),
  x :: non_neg_integer(),
  y :: non_neg_integer()
) :: String.t()
```

# `get_config`

```elixir
@callback get_config() :: map()
```

# `get_current_g_set`

```elixir
@callback get_current_g_set(buffer :: t()) :: atom() | integer()
```

# `get_current_state`

```elixir
@callback get_current_state(buffer :: t()) :: map()
```

# `get_designated_charset`

```elixir
@callback get_designated_charset(buffer :: t(), slot :: atom() | integer()) :: charset()
```

# `get_dimensions`

```elixir
@callback get_dimensions(buffer :: t()) :: dimensions()
```

# `get_foreground`

```elixir
@callback get_foreground(buffer :: t()) :: color()
```

# `get_height`

```elixir
@callback get_height(buffer :: t()) :: non_neg_integer()
```

# `get_metric`

```elixir
@callback get_metric(buffer :: t(), metric :: metric(), tags :: metric_tags()) ::
  metric_value()
```

# `get_metric_value`

```elixir
@callback get_metric_value(buffer :: t(), metric :: metric()) :: metric_value()
```

# `get_metrics_by_type`

```elixir
@callback get_metrics_by_type(buffer :: t(), type :: atom()) :: [map()]
```

# `get_output_buffer`

```elixir
@callback get_output_buffer(buffer :: t()) :: String.t()
```

# `get_preferences`

```elixir
@callback get_preferences() :: map()
```

# `get_saved_states_count`

```elixir
@callback get_saved_states_count(buffer :: t()) :: non_neg_integer()
```

# `get_scroll_position`

```elixir
@callback get_scroll_position(buffer :: t()) :: non_neg_integer()
```

# `get_scroll_region_boundaries`

```elixir
@callback get_scroll_region_boundaries(buffer :: t()) ::
  {non_neg_integer(), non_neg_integer()}
```

# `get_set_attributes`

```elixir
@callback get_set_attributes(buffer :: t()) :: [atom()]
```

# `get_single_shift`

```elixir
@callback get_single_shift(buffer :: t()) :: atom() | integer()
```

# `get_size`

```elixir
@callback get_size(buffer :: t()) :: dimensions()
```

# `get_state_stack`

```elixir
@callback get_state_stack(buffer :: t()) :: [map()]
```

# `get_style`

```elixir
@callback get_style(buffer :: t()) :: style()
```

# `get_update_settings`

```elixir
@callback get_update_settings() :: map()
```

# `get_width`

```elixir
@callback get_width(buffer :: t()) :: non_neg_integer()
```

# `handle_csi_sequence`

```elixir
@callback handle_csi_sequence(
  buffer :: t(),
  sequence :: String.t(),
  params :: [String.t()]
) :: t()
```

# `handle_debounced_events`

```elixir
@callback handle_debounced_events(
  buffer :: t(),
  events :: [map()],
  timeout :: non_neg_integer()
) :: t()
```

# `handle_file_event`

```elixir
@callback handle_file_event(buffer :: t(), event :: map()) :: t()
```

# `handle_mode`

```elixir
@callback handle_mode(buffer :: t(), mode :: atom(), value :: any()) :: t()
```

# `has_saved_states?`

```elixir
@callback has_saved_states?(buffer :: t()) :: boolean()
```

# `invoke_g_set`

```elixir
@callback invoke_g_set(buffer :: t(), slot :: atom() | integer()) :: t()
```

# `light_theme`

```elixir
@callback light_theme() :: map()
```

# `mark_damaged`

```elixir
@callback mark_damaged(
  buffer :: t(),
  x :: non_neg_integer(),
  y :: non_neg_integer(),
  width :: non_neg_integer(),
  height :: non_neg_integer()
) :: t()
```

# `new`

```elixir
@callback new(width :: non_neg_integer(), height :: non_neg_integer()) :: t()
```

# `record_metric`

```elixir
@callback record_metric(
  buffer :: t(),
  metric :: metric(),
  value :: metric_value(),
  tags :: metric_tags()
) :: t()
```

# `record_operation`

```elixir
@callback record_operation(
  buffer :: t(),
  operation :: atom(),
  value :: metric_value()
) :: t()
```

# `record_performance`

```elixir
@callback record_performance(
  buffer :: t(),
  metric :: metric(),
  value :: metric_value()
) :: t()
```

# `record_resource`

```elixir
@callback record_resource(
  buffer :: t(),
  resource :: atom(),
  value :: metric_value()
) :: t()
```

# `reset_all_attributes`

```elixir
@callback reset_all_attributes(buffer :: t()) :: t()
```

# `reset_attribute`

```elixir
@callback reset_attribute(buffer :: t(), attribute :: atom()) :: t()
```

# `reset_state`

```elixir
@callback reset_state(buffer :: t()) :: t()
```

# `restore_state`

```elixir
@callback restore_state(buffer :: t()) :: t()
```

# `save_state`

```elixir
@callback save_state(buffer :: t()) :: t()
```

# `scroll_down`

```elixir
@callback scroll_down(buffer :: t(), lines :: non_neg_integer()) :: t()
```

# `scroll_up`

```elixir
@callback scroll_up(buffer :: t(), lines :: non_neg_integer()) :: t()
```

# `set_attribute`

```elixir
@callback set_attribute(buffer :: t(), attribute :: atom()) :: t()
```

# `set_background`

```elixir
@callback set_background(buffer :: t(), color :: color()) :: t()
```

# `set_config`

```elixir
@callback set_config(config :: map()) :: :ok
```

# `set_foreground`

```elixir
@callback set_foreground(buffer :: t(), color :: color()) :: t()
```

# `set_preferences`

```elixir
@callback set_preferences(preferences :: map()) :: :ok
```

# `set_scroll_region`

```elixir
@callback set_scroll_region(
  buffer :: t(),
  start_line :: non_neg_integer(),
  end_line :: non_neg_integer()
) :: t()
```

# `update_current_state`

```elixir
@callback update_current_state(buffer :: t(), state :: map()) :: t()
```

# `update_state_stack`

```elixir
@callback update_state_stack(buffer :: t(), stack :: [map()]) :: t()
```

# `update_style`

```elixir
@callback update_style(buffer :: t(), style :: style()) :: t()
```

# `verify_metrics`

```elixir
@callback verify_metrics(buffer :: t(), metrics :: [metric()]) :: boolean()
```

# `write`

```elixir
@callback write(buffer :: t(), data :: String.t()) :: t()
```

# `write_char`

```elixir
@callback write_char(
  buffer :: t(),
  x :: non_neg_integer(),
  y :: non_neg_integer(),
  char :: String.t(),
  style :: style()
) :: t()
```

# `write_string`

```elixir
@callback write_string(
  buffer :: t(),
  x :: non_neg_integer(),
  y :: non_neg_integer(),
  string :: String.t(),
  style :: style()
) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
