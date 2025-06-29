defmodule Raxol.Terminal.ScreenBuffer.Core do
  @moduledoc """
  Core implementation of the screen buffer functionality.
  Implements the Raxol.Terminal.ScreenBufferBehaviour.
  """

  @behaviour Raxol.Terminal.ScreenBufferBehaviour

  alias Raxol.Terminal.ScreenBuffer.{
    Charset,
    Formatting,
    State,
    Output,
    Metrics,
    FileWatcher,
    Scroll,
    Screen,
    Mode,
    Visualizer,
    Preferences,
    System,
    Cloud,
    Theme,
    CSI
  }

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

  # --- Core Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def new(width, height, _scrollback \\ 1000) do
    %__MODULE__{
      cells: List.duplicate(List.duplicate(%{}, width), height),
      width: width,
      height: height,
      charset_state: Charset.init(),
      formatting_state: Formatting.init(),
      terminal_state: State.init(),
      output_buffer: "",
      metrics_state: Metrics.init(),
      file_watcher_state: FileWatcher.init(),
      scroll_state: Scroll.init(),
      screen_state: Screen.init(),
      mode_state: Mode.init(),
      visualizer_state: Visualizer.init(),
      preferences: Preferences.init(),
      system_state: System.init(),
      cloud_state: Cloud.init(),
      theme_state: Theme.init(),
      csi_state: CSI.init(),
      default_style: %{
        foreground: nil,
        background: nil,
        bold: false,
        italic: false,
        underline: false,
        blink: false,
        reverse: false,
        hidden: false,
        strikethrough: false
      }
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_char(buffer, x, y) do
    case Enum.at(buffer.cells, y) do
      nil -> " "
      row ->
        case Enum.at(row, x) do
          nil -> " "
          cell -> Raxol.Terminal.Cell.get_char(cell)
        end
    end
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_cell(buffer, x, y) do
    get_in(buffer.cells, [y, x]) || %{}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write_char(buffer, x, y, char, style) do
    cell = %{char: char, style: style}

    case get_in(buffer.cells, [y, x]) do
      nil ->
        # Cell doesn't exist, create it
        put_in(buffer.cells, [y, x], cell)

      existing_cell ->
        # Cell exists, update it
        updated_cell = Map.merge(existing_cell, cell)
        put_in(buffer.cells, [y, x], updated_cell)
    end
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write_string(buffer, x, y, string, style \\ nil) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, i}, acc ->
      write_char(acc, x + i, y, char, style)
    end)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_dimensions(buffer) do
    {buffer.width, buffer.height}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_width(buffer) do
    buffer.width
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_height(buffer) do
    buffer.height
  end

  # --- Clear Operations ---
  def clear(buffer, _style) do
    default_cell = %Raxol.Terminal.Cell{
      char: " ",
      style: nil,
      dirty: nil,
      wide_placeholder: false
    }

    %{
      buffer
      | cells:
          List.duplicate(
            List.duplicate(default_cell, buffer.width),
            buffer.height
          )
    }
  end

  def clear_line(buffer, line, _style \\ nil) do
    new_content =
      List.update_at(buffer.cells, line, fn _ ->
        List.duplicate(%{}, buffer.width)
      end)

    %{buffer | cells: new_content}
  end

  # --- Line Operations ---
  def insert_lines(buffer, count) do
    empty_line = List.duplicate(%{}, buffer.width)
    new_lines = List.duplicate(empty_line, count)
    new_content = new_lines ++ buffer.cells
    %{buffer | cells: Enum.take(new_content, buffer.height)}
  end

  def delete_lines(buffer, count) do
    empty_line = List.duplicate(%{}, buffer.width)
    new_lines = List.duplicate(empty_line, count)
    new_content = buffer.cells ++ new_lines
    %{buffer | cells: Enum.take(new_content, buffer.height)}
  end

  # --- Character Operations ---
  def insert_chars(buffer, count) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            empty_cells = List.duplicate(%{}, count)
            empty_cells ++ Enum.take(line, buffer.width - count)
          end)
    }
  end

  def delete_chars(buffer, count) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            empty_cells = List.duplicate(%{}, count)
            Enum.drop(line, count) ++ empty_cells
          end)
    }
  end

  def erase_chars(buffer, count) do
    %{
      buffer
      | cells:
          Enum.map(buffer.cells, fn line ->
            empty_cells = List.duplicate(%{}, count)
            Enum.take(line, buffer.width - count) ++ empty_cells
          end)
    }
  end

  def erase_chars(buffer, x, y, count) do
    # Erase characters starting at position (x, y)
    if y < length(buffer.cells) do
      line = Enum.at(buffer.cells, y, [])
      if x < length(line) do
        # Replace characters from x to x+count with empty cells
        new_line =
          Enum.take(line, x) ++
          List.duplicate(%{}, count) ++
          Enum.drop(line, x + count)

        new_cells = List.replace_at(buffer.cells, y, new_line)
        %{buffer | cells: new_cells}
      else
        buffer
      end
    else
      buffer
    end
  end

  # --- Erase Operations ---
  def erase_from_cursor_to_end(buffer) do
    %{
      buffer
      | screen_state: Screen.erase_from_cursor_to_end(buffer.screen_state)
    }
  end

  def erase_from_start_to_cursor(buffer) do
    %{
      buffer
      | screen_state: Screen.erase_from_start_to_cursor(buffer.screen_state)
    }
  end

  def erase_all(buffer) do
    %{buffer | screen_state: Screen.erase_all(buffer.screen_state)}
  end

  def erase_all_with_scrollback(buffer) do
    %{
      buffer
      | screen_state: Screen.erase_all_with_scrollback(buffer.screen_state)
    }
  end

  def erase_from_cursor_to_end_of_line(buffer) do
    %{
      buffer
      | screen_state:
          Screen.erase_from_cursor_to_end_of_line(buffer.screen_state)
    }
  end

  def erase_from_start_of_line_to_cursor(buffer) do
    %{
      buffer
      | screen_state:
          Screen.erase_from_start_of_line_to_cursor(buffer.screen_state)
    }
  end

  def erase_line(buffer) do
    %{buffer | screen_state: Screen.erase_line(buffer.screen_state)}
  end

  def erase_display(buffer, mode) do
    case mode do
      0 -> erase_from_cursor_to_end(buffer)
      1 -> erase_from_start_to_cursor(buffer)
      2 -> erase_all(buffer)
      3 -> erase_all(buffer)
      _ -> buffer
    end
  end

  # Add missing functions with different signatures
  def erase_display(buffer, mode, cursor, min_row, max_row) do
    # For now, delegate to the simpler version
    erase_display(buffer, mode)
  end

  def erase_line(buffer, mode, cursor, min_col, max_col) do
    # For now, delegate to the simpler version
    erase_line(buffer)
  end

  def delete_chars(buffer, count, cursor, max_col) do
    # For now, delegate to the simpler version
    delete_chars(buffer, count)
  end

  def insert_chars(buffer, count, cursor, max_col) do
    # For now, delegate to the simpler version
    insert_chars(buffer, count)
  end

  def mark_damaged(buffer, x, y, width, height, reason) do
    # For now, delegate to the simpler version
    mark_damaged(buffer, x, y, width, height)
  end

  def set_dimensions(buffer, width, height) do
    %{buffer | width: width, height: height}
  end

  def get_scrollback(buffer) do
    buffer.scroll_state
  end

  def set_scrollback(buffer, scrollback) do
    %{buffer | scroll_state: scrollback}
  end

  def get_damaged_regions(buffer) do
    Screen.get_damaged_regions(buffer.screen_state)
  end

  def clear_damaged_regions(buffer) do
    %{buffer | screen_state: Screen.clear_damaged_regions(buffer.screen_state)}
  end

  # --- Cursor Operations ---
  def get_cursor_position(buffer) do
    {buffer.terminal_state.cursor_x, buffer.terminal_state.cursor_y}
  end

  def set_cursor_position(buffer, x, y) do
    put_in(buffer.terminal_state, [:cursor_x], x)
    |> put_in([:terminal_state, :cursor_y], y)
  end

  # --- Region Operations ---
  def erase_region(buffer, x, y, width, height) do
    new_content =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row, acc ->
        List.update_at(acc, row, &erase_line_region(&1, x, width))
      end)

    %{buffer | cells: new_content}
  end

  defp erase_line_region(line, x, width) do
    Enum.reduce(x..(x + width - 1), line, fn col, line_acc ->
      List.update_at(line_acc, col, fn _ -> %{} end)
    end)
  end

  def mark_damaged(buffer, x, y, width, height) do
    %{
      buffer
      | screen_state:
          Screen.mark_damaged(buffer.screen_state, x, y, width, height)
    }
  end

  def clear_region(buffer, x, y, width, height) do
    buffer
    |> erase_region(x, y, width, height)
    |> mark_damaged(x, y, width, height)
  end

  # --- Scroll Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_size(buffer) do
    {buffer.width, buffer.height}
  end

  def scroll_up(buffer, lines) do
    %{buffer | scroll_state: Scroll.up(buffer.scroll_state, lines)}
  end

  def scroll_down(buffer, lines) do
    %{buffer | scroll_state: Scroll.down(buffer.scroll_state, lines)}
  end

  def set_scroll_region(buffer, start_line, end_line) do
    %{
      buffer
      | scroll_state:
          Scroll.set_region(buffer.scroll_state, start_line, end_line)
    }
  end

  def clear_scroll_region(buffer) do
    %{buffer | scroll_state: Scroll.clear_region(buffer.scroll_state)}
  end

  def get_scroll_region_boundaries(buffer) do
    Scroll.get_boundaries(buffer.scroll_state)
  end

  def get_scroll_position(buffer) do
    Scroll.get_position(buffer.scroll_state)
  end

  # --- Buffer Operations ---
  def pop_bottom_lines(buffer, count) do
    {lines, new_content} = Enum.split(buffer.cells, -count)
    {lines, %{buffer | cells: new_content}}
  end

  def push_top_lines(buffer, lines) do
    new_content = lines ++ buffer.cells
    %{buffer | cells: new_content}
  end

  # --- Charset Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def designate_charset(buffer, slot, charset) do
    %{
      buffer
      | charset_state: Charset.designate(buffer.charset_state, slot, charset)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def invoke_g_set(buffer, slot) do
    %{buffer | charset_state: Charset.invoke_g_set(buffer.charset_state, slot)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_current_g_set(buffer) do
    Charset.get_current_g_set(buffer.charset_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_designated_charset(buffer, slot) do
    Charset.get_designated(buffer.charset_state, slot)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_state(buffer) do
    %{buffer | charset_state: Charset.reset(buffer.charset_state)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def apply_single_shift(buffer, slot) do
    %{
      buffer
      | charset_state: Charset.apply_single_shift(buffer.charset_state, slot)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_single_shift(buffer) do
    Charset.get_single_shift(buffer.charset_state)
  end

  # --- Formatting Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_style(buffer) do
    Formatting.get_style(buffer.formatting_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_style(buffer, style) do
    %{
      buffer
      | formatting_state:
          Formatting.update_style(buffer.formatting_state, style)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_attribute(buffer, attribute) do
    %{
      buffer
      | formatting_state:
          Formatting.set_attribute(buffer.formatting_state, attribute)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_attribute(buffer, attribute) do
    %{
      buffer
      | formatting_state:
          Formatting.reset_attribute(buffer.formatting_state, attribute)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_foreground(buffer, color) do
    %{
      buffer
      | formatting_state:
          Formatting.set_foreground(buffer.formatting_state, color)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_background(buffer, color) do
    %{
      buffer
      | formatting_state:
          Formatting.set_background(buffer.formatting_state, color)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_all_attributes(buffer) do
    %{buffer | formatting_state: Formatting.reset_all(buffer.formatting_state)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_foreground(buffer) do
    Formatting.get_foreground(buffer.formatting_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_background(buffer) do
    Formatting.get_background(buffer.formatting_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def attribute_set?(buffer, attribute) do
    Formatting.attribute_set?(buffer.formatting_state, attribute)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_set_attributes(buffer) do
    Formatting.get_set_attributes(buffer.formatting_state)
  end

  # --- Terminal State Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_state_stack(buffer) do
    State.get_stack(buffer.terminal_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_state_stack(buffer, stack) do
    %{buffer | terminal_state: State.update_stack(buffer.terminal_state, stack)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def save_state(buffer) do
    %{buffer | terminal_state: State.save(buffer.terminal_state)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def restore_state(buffer) do
    %{buffer | terminal_state: State.restore(buffer.terminal_state)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def has_saved_states?(buffer) do
    State.has_saved_states?(buffer.terminal_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_saved_states_count(buffer) do
    State.get_saved_states_count(buffer.terminal_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_saved_states(buffer) do
    %{buffer | terminal_state: State.clear_saved_states(buffer.terminal_state)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_current_state(buffer) do
    State.get_current(buffer.terminal_state)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_current_state(buffer, state) do
    %{
      buffer
      | terminal_state: State.update_current(buffer.terminal_state, state)
    }
  end

  # --- Output Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write(buffer, data) do
    %{buffer | output_buffer: Output.write(buffer.output_buffer, data)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def flush_output(buffer) do
    %{buffer | output_buffer: Output.flush(buffer.output_buffer)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_output_buffer(buffer) do
    %{buffer | output_buffer: Output.clear(buffer.output_buffer)}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_output_buffer(buffer) do
    buffer.output_buffer
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def enqueue_control_sequence(buffer, sequence) do
    %{
      buffer
      | output_buffer:
          Output.enqueue_control_sequence(buffer.output_buffer, sequence)
    }
  end

  # --- Cell Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def empty?(cell) when is_map(cell) do
    is_nil(cell.char) or cell.char == " "
  end

  # --- Metrics Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metric_value(buffer, metric) do
    Metrics.get_value(buffer.metrics_state, metric)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def verify_metrics(buffer, metrics) do
    Metrics.verify(buffer.metrics_state, metrics)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def collect_metrics(buffer, metrics) do
    Metrics.collect(buffer.metrics_state, metrics)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_performance(buffer, metric, value) do
    %{
      buffer
      | metrics_state:
          Metrics.record_performance(buffer.metrics_state, metric, value)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_operation(buffer, operation, value) do
    %{
      buffer
      | metrics_state:
          Metrics.record_operation(buffer.metrics_state, operation, value)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_resource(buffer, resource, value) do
    %{
      buffer
      | metrics_state:
          Metrics.record_resource(buffer.metrics_state, resource, value)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metrics_by_type(buffer, type) do
    Metrics.get_by_type(buffer.metrics_state, type)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_metric(buffer, metric, value, tags) do
    %{
      buffer
      | metrics_state: Metrics.record(buffer.metrics_state, metric, value, tags)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metric(buffer, metric, tags) do
    Metrics.get(buffer.metrics_state, metric, tags)
  end

  # --- File Watcher Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_file_event(buffer, event) do
    %{
      buffer
      | file_watcher_state:
          FileWatcher.handle_event(buffer.file_watcher_state, event)
    }
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
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

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def cleanup_file_watching(buffer) do
    %{
      buffer
      | file_watcher_state: FileWatcher.cleanup(buffer.file_watcher_state)
    }
  end

  # --- Screen Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_screen(buffer) do
    %{buffer | screen_state: Screen.clear(buffer.screen_state)}
  end

  # --- Mode Handler Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_mode(buffer, mode, value) do
    %{buffer | mode_state: Mode.handle(buffer.mode_state, mode, value)}
  end

  # --- Visualizer Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def create_chart(buffer, data, options) do
    %{
      buffer
      | visualizer_state:
          Visualizer.create_chart(buffer.visualizer_state, data, options)
    }
  end

  # --- User Preferences Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_preferences do
    Preferences.get()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_preferences(preferences) do
    Preferences.set(preferences)
  end

  # --- System Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_update_settings do
    System.get_update_settings()
  end

  # --- Cloud Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_config do
    Cloud.get_config()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_config(config) do
    Cloud.set_config(config)
  end

  # --- Theme Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def current_theme do
    Theme.current()
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def light_theme do
    Theme.light()
  end

  # --- CSI Handler Operations ---
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_csi_sequence(buffer, sequence, params) do
    %{
      buffer
      | csi_state: CSI.handle_sequence(buffer.csi_state, sequence, params)
    }
  end

  def unimplemented(_args), do: :ok
end
