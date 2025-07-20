defmodule Raxol.Terminal.ScreenBuffer.BehaviourImpl do
  @moduledoc """
  Implements behaviour callbacks for the terminal screen buffer.

  This module contains all the simple behaviour callback implementations
  that were previously cluttering the main ScreenBuffer module.
  """

  alias Raxol.Terminal.Buffer.Eraser

  # === Behaviour Callback Implementations ===

  def cleanup_file_watching(buffer), do: buffer

  def clear_output_buffer(buffer), do: %{buffer | output_buffer: ""}

  def clear_saved_states(buffer), do: %{buffer | saved_states: []}

  def clear_screen(buffer), do: Eraser.clear(buffer)

  def collect_metrics(_buffer, _type), do: %{}

  def create_chart(buffer, _type, _options), do: buffer

  def current_theme, do: %{}

  def enqueue_control_sequence(buffer, _sequence), do: buffer

  def erase_all_with_scrollback(buffer), do: Eraser.clear(buffer)

  def erase_from_cursor_to_end_of_line(buffer) do
    {x, y} = get_cursor_position(buffer)
    Eraser.erase_line_segment(buffer, x, y)
  end

  def erase_from_start_of_line_to_cursor(buffer),
    do: Eraser.erase_from_start_of_line_to_cursor(buffer)

  def erase_from_start_to_cursor(buffer),
    do: Eraser.erase_from_start_to_cursor(buffer)

  def erase_line(buffer), do: Eraser.erase_line(buffer, 0)

  def flush_output(buffer), do: buffer

  def get_config, do: %{}

  def get_current_state(buffer), do: buffer.current_state || %{}

  def get_metric(_buffer, _type, _name), do: 0

  def get_metric_value(_buffer, _name), do: 0

  def get_metrics_by_type(_buffer, _type), do: []

  def get_output_buffer(buffer), do: buffer.output_buffer || ""

  def get_preferences, do: %{}

  def get_saved_states_count(buffer), do: length(buffer.saved_states || [])

  def get_size(buffer), do: {buffer.width, buffer.height}

  def get_state_stack(buffer), do: buffer.state_stack || []

  def get_update_settings, do: %{}

  def handle_csi_sequence(buffer, _command, _params), do: buffer

  def handle_debounced_events(buffer, _events, _delay), do: buffer

  def handle_file_event(buffer, _event), do: buffer

  def handle_mode(buffer, _mode, _value), do: buffer

  def has_saved_states?(buffer), do: length(buffer.saved_states || []) > 0

  def light_theme, do: %{}

  def mark_damaged(buffer, _x, _y, _width, _height), do: buffer

  def record_metric(buffer, _type, _name, _value), do: buffer

  def record_operation(buffer, _operation, _duration), do: buffer

  def record_performance(buffer, _metric, _value), do: buffer

  def record_resource(buffer, _type, _value), do: buffer

  def reset_state(buffer), do: %{buffer | current_state: %{}}

  def restore_state(buffer), do: buffer

  def save_state(buffer), do: buffer

  def set_config(_config), do: :ok

  def set_preferences(_preferences), do: :ok

  def update_current_state(buffer, _updates), do: buffer

  def update_state_stack(buffer, _stack), do: buffer

  def verify_metrics(_buffer, _type), do: true

  def write(buffer, _data), do: buffer

  # Private helper function
  defp get_cursor_position(buffer) do
    # This would typically delegate to the Cursor module
    buffer.cursor_position || {0, 0}
  end
end
