defmodule Raxol.Terminal.ScreenBuffer.Core.State do
  @moduledoc """
  Handles state management operations for the screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer.{
    Charset,
    Formatting,
    State,
    Output,
    Metrics,
    FileWatcher,
    Screen,
    Mode,
    Visualizer,
    Preferences,
    System,
    Cloud,
    Theme,
    CSI
  }

  @doc """
  Designates a charset for a specific slot.
  """
  def designate_charset(buffer, slot, charset) do
    %{
      buffer
      | charset_state: Charset.designate(buffer.charset_state, slot, charset)
    }
  end

  @doc """
  Invokes a G-set for a specific slot.
  """
  def invoke_g_set(buffer, slot) do
    %{buffer | charset_state: Charset.invoke_g_set(buffer.charset_state, slot)}
  end

  @doc """
  Gets the current G-set.
  """
  def get_current_g_set(buffer) do
    Charset.get_current_g_set(buffer.charset_state)
  end

  @doc """
  Gets the designated charset for a specific slot.
  """
  def get_designated_charset(buffer, slot) do
    Charset.get_designated(buffer.charset_state, slot)
  end

  @doc """
  Resets the charset state.
  """
  def reset_state(buffer) do
    %{buffer | charset_state: Charset.reset(buffer.charset_state)}
  end

  @doc """
  Applies single shift for a specific slot.
  """
  def apply_single_shift(buffer, slot) do
    %{
      buffer
      | charset_state: Charset.apply_single_shift(buffer.charset_state, slot)
    }
  end

  @doc """
  Gets the single shift state.
  """
  def get_single_shift(buffer) do
    Charset.get_single_shift(buffer.charset_state)
  end

  @doc """
  Gets the current style.
  """
  def get_style(buffer) do
    Formatting.get_style(buffer.formatting_state)
  end

  @doc """
  Updates the style.
  """
  def update_style(buffer, style) do
    %{
      buffer
      | formatting_state:
          Formatting.update_style(buffer.formatting_state, style)
    }
  end

  @doc """
  Sets an attribute.
  """
  def set_attribute(buffer, attribute) do
    %{
      buffer
      | formatting_state:
          Formatting.set_attribute(buffer.formatting_state, attribute)
    }
  end

  @doc """
  Resets an attribute.
  """
  def reset_attribute(buffer, attribute) do
    %{
      buffer
      | formatting_state:
          Formatting.reset_attribute(buffer.formatting_state, attribute)
    }
  end

  @doc """
  Sets foreground color.
  """
  def set_foreground(buffer, color) do
    %{
      buffer
      | formatting_state:
          Formatting.set_foreground(buffer.formatting_state, color)
    }
  end

  @doc """
  Sets background color.
  """
  def set_background(buffer, color) do
    %{
      buffer
      | formatting_state:
          Formatting.set_background(buffer.formatting_state, color)
    }
  end

  @doc """
  Resets all attributes.
  """
  def reset_all_attributes(buffer) do
    %{buffer | formatting_state: Formatting.reset_all(buffer.formatting_state)}
  end

  @doc """
  Gets foreground color.
  """
  def get_foreground(buffer) do
    Formatting.get_foreground(buffer.formatting_state)
  end

  @doc """
  Gets background color.
  """
  def get_background(buffer) do
    Formatting.get_background(buffer.formatting_state)
  end

  @doc """
  Checks if an attribute is set.
  """
  def attribute_set?(buffer, attribute) do
    Formatting.attribute_set?(buffer.formatting_state, attribute)
  end

  @doc """
  Gets all set attributes.
  """
  def get_set_attributes(buffer) do
    Formatting.get_set_attributes(buffer.formatting_state)
  end

  @doc """
  Gets the state stack.
  """
  def get_state_stack(buffer) do
    State.get_stack(buffer.terminal_state)
  end

  @doc """
  Updates the state stack.
  """
  def update_state_stack(buffer, stack) do
    %{buffer | terminal_state: State.update_stack(buffer.terminal_state, stack)}
  end

  @doc """
  Saves the current state.
  """
  def save_state(buffer) do
    %{buffer | terminal_state: State.save(buffer.terminal_state)}
  end

  @doc """
  Restores the saved state.
  """
  def restore_state(buffer) do
    %{buffer | terminal_state: State.restore(buffer.terminal_state)}
  end

  @doc """
  Checks if there are saved states.
  """
  def has_saved_states?(buffer) do
    State.has_saved_states?(buffer.terminal_state)
  end

  @doc """
  Gets the count of saved states.
  """
  def get_saved_states_count(buffer) do
    State.get_saved_states_count(buffer.terminal_state)
  end

  @doc """
  Clears all saved states.
  """
  def clear_saved_states(buffer) do
    %{buffer | terminal_state: State.clear_saved_states(buffer.terminal_state)}
  end

  @doc """
  Gets the current state.
  """
  def get_current_state(buffer) do
    State.get_current(buffer.terminal_state)
  end

  @doc """
  Updates the current state.
  """
  def update_current_state(buffer, state) do
    %{
      buffer
      | terminal_state: State.update_current(buffer.terminal_state, state)
    }
  end

  @doc """
  Writes data to the output buffer.
  """
  def write(buffer, data) do
    %{buffer | output_buffer: Output.write(buffer.output_buffer, data)}
  end

  @doc """
  Flushes the output buffer.
  """
  def flush_output(buffer) do
    %{buffer | output_buffer: Output.flush(buffer.output_buffer)}
  end

  @doc """
  Clears the output buffer.
  """
  def clear_output_buffer(buffer) do
    %{buffer | output_buffer: Output.clear(buffer.output_buffer)}
  end

  @doc """
  Gets the output buffer.
  """
  def get_output_buffer(buffer) do
    buffer.output_buffer
  end

  @doc """
  Enqueues a control sequence.
  """
  def enqueue_control_sequence(buffer, sequence) do
    %{
      buffer
      | output_buffer:
          Output.enqueue_control_sequence(buffer.output_buffer, sequence)
    }
  end

  @doc """
  Gets a metric value.
  """
  def get_metric_value(buffer, metric) do
    Metrics.get_value(buffer.metrics_state, metric)
  end

  @doc """
  Verifies metrics.
  """
  def verify_metrics(buffer, metrics) do
    Metrics.verify(buffer.metrics_state, metrics)
  end

  @doc """
  Collects metrics.
  """
  def collect_metrics(buffer, metrics) do
    Metrics.collect(buffer.metrics_state, metrics)
  end

  @doc """
  Records performance metrics.
  """
  def record_performance(buffer, metric, value) do
    %{
      buffer
      | metrics_state:
          Metrics.record_performance(buffer.metrics_state, metric, value)
    }
  end

  @doc """
  Records operation metrics.
  """
  def record_operation(buffer, operation, value) do
    %{
      buffer
      | metrics_state:
          Metrics.record_operation(buffer.metrics_state, operation, value)
    }
  end

  @doc """
  Records resource metrics.
  """
  def record_resource(buffer, resource, value) do
    %{
      buffer
      | metrics_state:
          Metrics.record_resource(buffer.metrics_state, resource, value)
    }
  end

  @doc """
  Gets metrics by type.
  """
  def get_metrics_by_type(buffer, type) do
    Metrics.get_by_type(buffer.metrics_state, type)
  end

  @doc """
  Records a metric with tags.
  """
  def record_metric(buffer, metric, value, tags) do
    %{
      buffer
      | metrics_state: Metrics.record(buffer.metrics_state, metric, value, tags)
    }
  end

  @doc """
  Gets a metric with tags.
  """
  def get_metric(buffer, metric, tags) do
    Metrics.get(buffer.metrics_state, metric, tags)
  end

  @doc """
  Handles file events.
  """
  def handle_file_event(buffer, event) do
    %{
      buffer
      | file_watcher_state:
          FileWatcher.handle_event(buffer.file_watcher_state, event)
    }
  end

  @doc """
  Handles debounced events.
  """
  def handle_debounced_events(buffer, events, timeout) do
    %{
      buffer
      | file_watcher_state:
          FileWatcher.handle_debounced(
            buffer.file_watcher_state,
            events,
            timeout
          )
    }
  end

  @doc """
  Cleans up file watching.
  """
  def cleanup_file_watching(buffer) do
    %{
      buffer
      | file_watcher_state: FileWatcher.cleanup(buffer.file_watcher_state)
    }
  end

  @doc """
  Clears the screen.
  """
  def clear_screen(buffer) do
    %{buffer | screen_state: Screen.clear(buffer.screen_state)}
  end

  @doc """
  Handles mode changes.
  """
  def handle_mode(buffer, mode, value) do
    %{buffer | mode_state: Mode.handle(buffer.mode_state, mode, value)}
  end

  @doc """
  Creates a chart.
  """
  def create_chart(buffer, data, options) do
    %{
      buffer
      | visualizer_state:
          Visualizer.create_chart(buffer.visualizer_state, data, options)
    }
  end

  @doc """
  Gets user preferences.
  """
  def get_preferences do
    Preferences.get()
  end

  @doc """
  Sets user preferences.
  """
  def set_preferences(preferences) do
    Preferences.set(preferences)
  end

  @doc """
  Gets update settings.
  """
  def get_update_settings do
    System.get_update_settings()
  end

  @doc """
  Gets cloud configuration.
  """
  def get_config do
    Cloud.get_config()
  end

  @doc """
  Sets cloud configuration.
  """
  def set_config(config) do
    Cloud.set_config(config)
  end

  @doc """
  Gets current theme.
  """
  def current_theme do
    Theme.current()
  end

  @doc """
  Gets light theme.
  """
  def light_theme do
    Theme.light()
  end

  @doc """
  Handles CSI sequences.
  """
  def handle_csi_sequence(buffer, sequence, params) do
    %{
      buffer
      | csi_state: CSI.handle_sequence(buffer.csi_state, sequence, params)
    }
  end
end
