defmodule Raxol.Terminal.ScreenManager do
  @moduledoc """
  Manages screen buffer operations for the terminal emulator.
  This module handles operations related to the main and alternate screen buffers,
  including buffer switching, initialization, and state management.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ScreenBuffer.Manager

  @doc """
  Gets the currently active screen buffer.
  """
  def get_screen_buffer(%{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_screen_buffer(%{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the currently active screen buffer.
  """
  def update_active_buffer(%{active_buffer_type: :main} = emulator, new_buffer) do
    %{emulator | main_screen_buffer: new_buffer}
  end

  def update_active_buffer(
        %{active_buffer_type: :alternate} = emulator,
        new_buffer
      ) do
    %{emulator | alternate_screen_buffer: new_buffer}
  end

  @doc """
  Switches between main and alternate screen buffers.
  """
  def switch_buffer(emulator) do
    new_type =
      case emulator.active_buffer_type do
        :main -> :alternate
        :alternate -> :main
        _ -> :main
      end

    %{emulator | active_buffer_type: new_type}
  end

  @doc """
  Initializes both main and alternate screen buffers.
  """
  def initialize_buffers(width, height, scrollback_limit) do
    Manager.initialize_buffers(width, height, scrollback_limit)
  end

  @doc """
  Initializes both main and alternate screen buffers with default scrollback limit.
  """
  def initialize_buffers(width, height) do
    initialize_buffers(width, height, 1000)
  end

  @doc """
  Resizes both screen buffers.
  """
  def resize_buffers(emulator, new_width, new_height) do
    new_main_buffer =
      ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)

    new_alt_buffer =
      ScreenBuffer.resize(
        emulator.alternate_screen_buffer,
        new_width,
        new_height
      )

    %{
      emulator
      | main_screen_buffer: new_main_buffer,
        alternate_screen_buffer: new_alt_buffer,
        width: new_width,
        height: new_height
    }
  end

  @doc """
  Gets the current buffer type (main or alternate).
  """
  def get_buffer_type(emulator) do
    emulator.active_buffer_type
  end

  @doc """
  Sets the buffer type.
  """
  def set_buffer_type(emulator, type) when type in [:main, :alternate] do
    %{emulator | active_buffer_type: type}
  end

  @doc """
  Gets the scroll region from the active buffer.
  """
  def get_scroll_region(buffer) do
    ScreenBuffer.get_scroll_region(buffer)
  end

  @doc """
  Sets the scroll region on the buffer.
  """
  def set_scroll_region(buffer, {top, bottom}) do
    ScreenBuffer.set_scroll_region(buffer, {top, bottom})
  end

  @doc """
  Gets the scroll top from the active buffer.
  """
  def get_scroll_top(buffer) do
    ScreenBuffer.get_scroll_top(buffer)
  end

  @doc """
  Gets the scroll bottom from the active buffer.
  """
  def get_scroll_bottom(buffer) do
    ScreenBuffer.get_scroll_bottom(buffer)
  end

  # Selection-related functions

  @doc """
  Gets the current selection from the buffer.
  """
  def get_selection(buffer) do
    ScreenBuffer.get_selection(buffer)
  end

  @doc """
  Gets the selected text from the buffer.
  """
  def get_selected_text(buffer) do
    ScreenBuffer.get_selected_text(buffer)
  end

  @doc """
  Gets the selection start coordinates.
  """
  def get_selection_start(buffer) do
    ScreenBuffer.get_selection_start(buffer)
  end

  @doc """
  Gets the selection end coordinates.
  """
  def get_selection_end(buffer) do
    ScreenBuffer.get_selection_end(buffer)
  end

  @doc """
  Gets the selection boundaries as {start, end} tuple.
  """
  def get_selection_boundaries(buffer) do
    ScreenBuffer.get_selection_boundaries(buffer)
  end

  @doc """
  Starts a selection at the specified position.
  """
  def start_selection(buffer, x, y) do
    ScreenBuffer.start_selection(buffer, x, y)
  end

  @doc """
  Updates the selection end position.
  """
  def update_selection(buffer, x, y) do
    ScreenBuffer.update_selection(buffer, x, y)
  end

  @doc """
  Clears the current selection.
  """
  def clear_selection(buffer) do
    ScreenBuffer.clear_selection(buffer)
  end

  @doc """
  Checks if a selection is currently active.
  """
  def selection_active?(buffer) do
    ScreenBuffer.selection_active?(buffer)
  end

  @doc """
  Checks if a position is within the current selection.
  """
  def in_selection?(buffer, x, y) do
    ScreenBuffer.in_selection?(buffer, x, y)
  end

  @doc """
  Writes a string to the buffer at the given position with the given style.
  """
  def write_string(buffer, x, y, string, style) do
    Raxol.Terminal.ScreenBuffer.write_string(buffer, x, y, string, style)
  end

  @doc """
  Parses scrollback limit from options, defaulting to 1000.
  """
  def parse_scrollback_limit(opts) do
    Keyword.get(opts, :scrollback_limit, 1000)
  end

  # === Additional ScreenManager Functions ===

  @doc """
  Gets the style at a specific position.
  """
  def get_style_at(buffer, x, y) do
    case ScreenBuffer.get_cell(buffer, x, y) do
      %{style: style} when not is_nil(style) -> style
      _ -> %{}
    end
  end

  @doc """
  Gets the style at the cursor position.
  """
  def get_style_at_cursor(buffer) do
    {x, y} = buffer.cursor_position
    get_style_at(buffer, x, y)
  end

  @doc """
  Gets the current state of the buffer.
  """
  def get_state(buffer) do
    %{
      width: buffer.width,
      height: buffer.height,
      cursor_position: buffer.cursor_position,
      scroll_region: buffer.scroll_region,
      selection: buffer.selection
    }
  end

  @doc """
  Gets the current style of the buffer.
  """
  def get_style(buffer) do
    buffer.default_style || %{}
  end
end
