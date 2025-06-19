defmodule Raxol.Terminal.OperationsBehaviour do
  @moduledoc """
  Defines the behaviour for core terminal operations.

  This behaviour consolidates all the essential terminal operations that were previously
  missing proper behaviour definitions. It includes operations for:
  - Cursor management
  - Screen manipulation
  - Text input/output
  - Selection handling
  - Display control
  """

  alias Raxol.Terminal.Cell

  @type t :: term()
  @type position :: {non_neg_integer(), non_neg_integer()}
  @type dimensions :: {non_neg_integer(), non_neg_integer()}
  @type style :: map() | nil
  @type color :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type scroll_region :: {non_neg_integer(), non_neg_integer()}

  # --- Cursor Operations ---
  @callback get_cursor_position(t()) :: position()
  @callback set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
  @callback get_cursor_style(t()) :: atom()
  @callback set_cursor_style(t(), atom()) :: t()
  @callback is_cursor_visible?(t()) :: boolean()
  @callback set_cursor_visibility(t(), boolean()) :: t()
  @callback is_cursor_blinking?(t()) :: boolean()
  @callback set_cursor_blink(t(), boolean()) :: t()
  @callback toggle_visibility(t()) :: t()
  @callback toggle_blink(t()) :: t()
  @callback set_blink_rate(t(), non_neg_integer()) :: t()
  @callback update_blink(t()) :: t()

  # --- Screen Operations ---
  @callback clear_screen(t()) :: t()
  @callback clear_line(t(), non_neg_integer()) :: t()
  @callback erase_display(t(), atom()) :: t()
  @callback erase_in_display(t(), atom()) :: t()
  @callback erase_line(t(), atom()) :: t()
  @callback erase_in_line(t(), atom()) :: t()
  @callback erase_from_cursor_to_end(t()) :: t()
  @callback erase_from_start_to_cursor(t()) :: t()
  @callback erase_chars(t(), non_neg_integer()) :: t()
  @callback delete_chars(t(), non_neg_integer()) :: t()
  @callback insert_chars(t(), non_neg_integer()) :: t()
  @callback delete_lines(t(), non_neg_integer()) :: t()
  @callback insert_lines(t(), non_neg_integer()) :: t()
  @callback prepend_lines(t(), non_neg_integer()) :: t()

  # --- Text Operations ---
  @callback write_string(t(), non_neg_integer(), non_neg_integer(), String.t(), style()) :: t()
  @callback get_text_in_region(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  @callback get_content(t()) :: list(list(Cell.t()))
  @callback get_line(t(), non_neg_integer()) :: list(Cell.t())
  @callback get_cell_at(t(), non_neg_integer(), non_neg_integer()) :: Cell.t()

  # --- Selection Operations ---
  @callback get_selection(t()) :: {position(), position()}
  @callback get_selection_start(t()) :: position()
  @callback get_selection_end(t()) :: position()
  @callback get_selection_boundaries(t()) :: {position(), position()}
  @callback start_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  @callback update_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  @callback clear_selection(t()) :: t()
  @callback selection_active?(t()) :: boolean()
  @callback in_selection?(t(), non_neg_integer(), non_neg_integer()) :: boolean()

  # --- Scroll Operations ---
  @callback get_scroll_region(t()) :: scroll_region()
  @callback set_scroll_region(t(), scroll_region()) :: t()
  @callback get_scroll_top(t()) :: non_neg_integer()
  @callback get_scroll_bottom(t()) :: non_neg_integer()

  # --- State Management ---
  @callback get_state(t()) :: map()
  @callback get_style(t()) :: style()
  @callback reset_charset_state(t()) :: t()
  @callback resolve_load_order(t()) :: t()
  @callback cleanup(t()) :: t()
  @callback stop(t()) :: t()
end
