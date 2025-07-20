defmodule Raxol.Terminal.ScreenBuffer.Core do
  @moduledoc """
  Core implementation of the screen buffer functionality.
  Implements the Raxol.Terminal.ScreenBufferBehaviour.
  """

  @behaviour Raxol.Terminal.ScreenBufferBehaviour

  alias Raxol.Terminal.ScreenBuffer.Core.{
    Initialization,
    Operations,
    State,
    Utils
  }

  # Delegate struct and type to Initialization module
  defstruct [
    :cells,
    :width,
    :height,
    :charset_state,
    :formatting_state,
    :terminal_state,
    :output_buffer,
    :metrics_state,
    :file_watcher_state,
    :scroll_state,
    :screen_state,
    :mode_state,
    :visualizer_state,
    :preferences,
    :system_state,
    :cloud_state,
    :theme_state,
    :csi_state,
    :default_style
  ]

  @type t :: %__MODULE__{
          cells: list(list(map())),
          width: non_neg_integer(),
          height: non_neg_integer(),
          charset_state: map(),
          formatting_state: map(),
          terminal_state: map(),
          output_buffer: String.t(),
          metrics_state: map(),
          file_watcher_state: map(),
          scroll_state: map(),
          screen_state: map(),
          mode_state: map(),
          visualizer_state: map(),
          preferences: map(),
          system_state: map(),
          cloud_state: map(),
          theme_state: map(),
          csi_state: map(),
          default_style: map()
        }

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def new(width, height, scrollback \\ 1000) do
    Initialization.new(width, height, scrollback)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_char(buffer, x, y) do
    Operations.get_char(buffer, x, y)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_cell(buffer, x, y) do
    Operations.get_cell(buffer, x, y)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write_char(buffer, x, y, char, style) do
    Operations.write_char(buffer, x, y, char, style)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write_string(buffer, x, y, string, style \\ nil) do
    Operations.write_string(buffer, x, y, string, style)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_dimensions(buffer) do
    Utils.get_dimensions(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_width(buffer) do
    Utils.get_width(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_height(buffer) do
    Utils.get_height(buffer)
  end

  def clear(buffer, style) do
    Operations.clear(buffer, style)
  end

  def clear_line(buffer, line, style \\ nil) do
    Operations.clear_line(buffer, line, style)
  end

  def insert_lines(buffer, count) do
    Operations.insert_lines(buffer, count)
  end

  def delete_lines(buffer, count) do
    Operations.delete_lines(buffer, count)
  end

  def insert_chars(buffer, count) do
    Operations.insert_chars(buffer, count)
  end

  def delete_chars(buffer, count) do
    Operations.delete_chars(buffer, count)
  end

  def erase_chars(buffer, count) do
    Operations.erase_chars(buffer, count)
  end

  def erase_chars(buffer, x, y, count) do
    Operations.erase_chars(buffer, x, y, count)
  end

  def erase_from_cursor_to_end(buffer) do
    Operations.erase_from_cursor_to_end(buffer)
  end

  def erase_from_start_to_cursor(buffer) do
    Operations.erase_from_start_to_cursor(buffer)
  end

  def erase_all(buffer) do
    Operations.erase_all(buffer)
  end

  def erase_all_with_scrollback(buffer) do
    Operations.erase_all_with_scrollback(buffer)
  end

  def erase_from_cursor_to_end_of_line(buffer) do
    Operations.erase_from_cursor_to_end_of_line(buffer)
  end

  def erase_from_start_of_line_to_cursor(buffer) do
    Operations.erase_from_start_of_line_to_cursor(buffer)
  end

  def erase_line(buffer) do
    Operations.erase_line(buffer)
  end

  def erase_display(buffer, mode) do
    Operations.erase_display(buffer, mode)
  end

  def erase_display(buffer, mode, cursor, min_row, max_row) do
    Operations.erase_display(buffer, mode, cursor, min_row, max_row)
  end

  def erase_line(buffer, mode, cursor, min_col, max_col) do
    Operations.erase_line(buffer, mode, cursor, min_col, max_col)
  end

  def delete_chars(buffer, count, cursor, max_col) do
    Operations.delete_chars(buffer, count, cursor, max_col)
  end

  def insert_chars(buffer, count, cursor, max_col) do
    Operations.insert_chars(buffer, count, cursor, max_col)
  end

  def mark_damaged(buffer, x, y, width, height, reason) do
    Operations.mark_damaged(buffer, x, y, width, height, reason)
  end

  def set_dimensions(buffer, width, height) do
    Operations.set_dimensions(buffer, width, height)
  end

  def get_scrollback(buffer) do
    Operations.get_scrollback(buffer)
  end

  def set_scrollback(buffer, scrollback) do
    Operations.set_scrollback(buffer, scrollback)
  end

  def get_damaged_regions(buffer) do
    Operations.get_damaged_regions(buffer)
  end

  def clear_damaged_regions(buffer) do
    Operations.clear_damaged_regions(buffer)
  end

  def get_cursor_position(buffer) do
    Operations.get_cursor_position(buffer)
  end

  def set_cursor_position(buffer, x, y) do
    Operations.set_cursor_position(buffer, x, y)
  end

  def erase_region(buffer, x, y, width, height) do
    Operations.erase_region(buffer, x, y, width, height)
  end

  def mark_damaged(buffer, x, y, width, height) do
    Operations.mark_damaged(buffer, x, y, width, height)
  end

  def clear_region(buffer, x, y, width, height) do
    Operations.clear_region(buffer, x, y, width, height)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_size(buffer) do
    Operations.get_size(buffer)
  end

  def scroll_up(buffer, lines) do
    Operations.scroll_up(buffer, lines)
  end

  def scroll_down(buffer, lines) do
    Operations.scroll_down(buffer, lines)
  end

  def set_scroll_region(buffer, start_line, end_line) do
    Operations.set_scroll_region(buffer, start_line, end_line)
  end

  def clear_scroll_region(buffer) do
    Operations.clear_scroll_region(buffer)
  end

  def get_scroll_region_boundaries(buffer) do
    Operations.get_scroll_region_boundaries(buffer)
  end

  def get_scroll_position(buffer) do
    Operations.get_scroll_position(buffer)
  end

  def pop_bottom_lines(buffer, count) do
    Operations.pop_bottom_lines(buffer, count)
  end

  def push_top_lines(buffer, lines) do
    Operations.push_top_lines(buffer, lines)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def designate_charset(buffer, slot, charset) do
    State.designate_charset(buffer, slot, charset)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def invoke_g_set(buffer, slot) do
    State.invoke_g_set(buffer, slot)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_current_g_set(buffer) do
    State.get_current_g_set(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_designated_charset(buffer, slot) do
    State.get_designated_charset(buffer, slot)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_state(buffer) do
    State.reset_state(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def apply_single_shift(buffer, slot) do
    State.apply_single_shift(buffer, slot)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_single_shift(buffer) do
    State.get_single_shift(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_style(buffer) do
    State.get_style(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_style(buffer, style) do
    State.update_style(buffer, style)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_attribute(buffer, attribute) do
    State.set_attribute(buffer, attribute)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_attribute(buffer, attribute) do
    State.reset_attribute(buffer, attribute)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_foreground(buffer, color) do
    State.set_foreground(buffer, color)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_background(buffer, color) do
    State.set_background(buffer, color)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_all_attributes(buffer) do
    State.reset_all_attributes(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_foreground(buffer) do
    State.get_foreground(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_background(buffer) do
    State.get_background(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def attribute_set?(buffer, attribute) do
    State.attribute_set?(buffer, attribute)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_set_attributes(buffer) do
    State.get_set_attributes(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_state_stack(buffer) do
    State.get_state_stack(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_state_stack(buffer, stack) do
    State.update_state_stack(buffer, stack)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def save_state(buffer) do
    State.save_state(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def restore_state(buffer) do
    State.restore_state(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def has_saved_states?(buffer) do
    State.has_saved_states?(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_saved_states_count(buffer) do
    State.get_saved_states_count(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_saved_states(buffer) do
    State.clear_saved_states(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_current_state(buffer) do
    State.get_current_state(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_current_state(buffer, state) do
    State.update_current_state(buffer, state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write(buffer, data) do
    State.write(buffer, data)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def flush_output(buffer) do
    State.flush_output(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_output_buffer(buffer) do
    State.clear_output_buffer(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_output_buffer(buffer) do
    State.get_output_buffer(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def enqueue_control_sequence(buffer, sequence) do
    State.enqueue_control_sequence(buffer, sequence)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def empty?(cell) when is_map(cell) do
    Operations.empty?(cell)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metric_value(buffer, metric) do
    State.get_metric_value(buffer, metric)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def verify_metrics(buffer, metrics) do
    State.verify_metrics(buffer, metrics)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def collect_metrics(buffer, metrics) do
    State.collect_metrics(buffer, metrics)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_performance(buffer, metric, value) do
    State.record_performance(buffer, metric, value)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_operation(buffer, operation, value) do
    State.record_operation(buffer, operation, value)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_resource(buffer, resource, value) do
    State.record_resource(buffer, resource, value)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metrics_by_type(buffer, type) do
    State.get_metrics_by_type(buffer, type)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_metric(buffer, metric, value, tags) do
    State.record_metric(buffer, metric, value, tags)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metric(buffer, metric, tags) do
    State.get_metric(buffer, metric, tags)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_file_event(buffer, event) do
    State.handle_file_event(buffer, event)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_debounced_events(buffer, events, timeout) do
    State.handle_debounced_events(buffer, events, timeout)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def cleanup_file_watching(buffer) do
    State.cleanup_file_watching(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_screen(buffer) do
    State.clear_screen(buffer)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_mode(buffer, mode, value) do
    State.handle_mode(buffer, mode, value)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def create_chart(buffer, data, options) do
    State.create_chart(buffer, data, options)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_preferences do
    State.get_preferences()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_preferences(preferences) do
    State.set_preferences(preferences)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_update_settings do
    State.get_update_settings()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_config do
    State.get_config()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_config(config) do
    State.set_config(config)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def current_theme do
    State.current_theme()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def light_theme do
    State.light_theme()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_csi_sequence(buffer, sequence, params) do
    State.handle_csi_sequence(buffer, sequence, params)
  end

  def unimplemented(args), do: Utils.unimplemented(args)
end
