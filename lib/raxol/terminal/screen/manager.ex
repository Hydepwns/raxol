defmodule Raxol.Terminal.ScreenManager do
  @moduledoc """
  Manages screen buffer operations for the terminal emulator.
  This module handles operations related to the main and alternate screen buffers,
  including buffer switching, initialization, and state management.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Manager
  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Gets the currently active screen buffer.
  """
  @spec get_active_buffer(EmulatorStruct.t()) :: ScreenBuffer.t()
  def get_active_buffer(%{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_active_buffer(%{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the currently active screen buffer.
  """
  @spec update_active_buffer(EmulatorStruct.t(), ScreenBuffer.t()) ::
          EmulatorStruct.t()
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
  @spec switch_buffer(EmulatorStruct.t()) :: EmulatorStruct.t()
  def switch_buffer(emulator) do
    new_type =
      if emulator.active_buffer_type == :main, do: :alternate, else: :main

    %{emulator | active_buffer_type: new_type}
  end

  @doc """
  Initializes both main and alternate screen buffers.
  """
  @spec initialize_buffers(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {ScreenBuffer.t(), ScreenBuffer.t()}
  def initialize_buffers(width, height, scrollback_limit) do
    Manager.initialize_buffers(width, height, scrollback_limit)
  end

  @doc """
  Resizes both screen buffers.
  """
  @spec resize_buffers(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) ::
          EmulatorStruct.t()
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
  @spec get_buffer_type(EmulatorStruct.t()) :: :main | :alternate
  def get_buffer_type(emulator) do
    emulator.active_buffer_type
  end

  @doc """
  Sets the buffer type.
  """
  @spec set_buffer_type(EmulatorStruct.t(), :main | :alternate) ::
          EmulatorStruct.t()
  def set_buffer_type(emulator, type) when type in [:main, :alternate] do
    %{emulator | active_buffer_type: type}
  end

  @doc """
  Gets the scroll region from the active buffer.
  """
  @spec get_scroll_region(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_scroll_region(buffer) do
    ScreenBuffer.get_scroll_region(buffer)
  end

  @doc """
  Sets the scroll region on the buffer.
  """
  @spec set_scroll_region(ScreenBuffer.t(), {non_neg_integer(), non_neg_integer()}) ::
          ScreenBuffer.t()
  def set_scroll_region(buffer, {top, bottom}) do
    ScreenBuffer.set_scroll_region(buffer, {top, bottom})
  end

  @doc """
  Gets the scroll top from the active buffer.
  """
  @spec get_scroll_top(ScreenBuffer.t()) :: non_neg_integer()
  def get_scroll_top(buffer) do
    ScreenBuffer.get_scroll_top(buffer)
  end

  @doc """
  Gets the scroll bottom from the active buffer.
  """
  @spec get_scroll_bottom(ScreenBuffer.t()) :: non_neg_integer()
  def get_scroll_bottom(buffer) do
    ScreenBuffer.get_scroll_bottom(buffer)
  end

  # Selection-related functions

  @doc """
  Gets the current selection from the buffer.
  """
  @spec get_selection(ScreenBuffer.t()) :: String.t()
  def get_selection(buffer) do
    ScreenBuffer.get_selection(buffer)
  end

  @doc """
  Gets the selection start coordinates.
  """
  @spec get_selection_start(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_selection_start(buffer) do
    ScreenBuffer.get_selection_start(buffer)
  end

  @doc """
  Gets the selection end coordinates.
  """
  @spec get_selection_end(ScreenBuffer.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_selection_end(buffer) do
    ScreenBuffer.get_selection_end(buffer)
  end

  @doc """
  Gets the selection boundaries as {start, end} tuple.
  """
  @spec get_selection_boundaries(ScreenBuffer.t()) :: {{non_neg_integer(), non_neg_integer()}, {non_neg_integer(), non_neg_integer()}} | nil
  def get_selection_boundaries(buffer) do
    ScreenBuffer.get_selection_boundaries(buffer)
  end

  @doc """
  Starts a selection at the specified position.
  """
  @spec start_selection(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def start_selection(buffer, x, y) do
    ScreenBuffer.start_selection(buffer, x, y)
  end

  @doc """
  Updates the selection end position.
  """
  @spec update_selection(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def update_selection(buffer, x, y) do
    ScreenBuffer.update_selection(buffer, x, y)
  end

  @doc """
  Clears the current selection.
  """
  @spec clear_selection(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_selection(buffer) do
    ScreenBuffer.clear_selection(buffer)
  end

  @doc """
  Checks if a selection is currently active.
  """
  @spec selection_active?(ScreenBuffer.t()) :: boolean()
  def selection_active?(buffer) do
    ScreenBuffer.selection_active?(buffer)
  end

  @doc """
  Checks if a position is within the current selection.
  """
  @spec in_selection?(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def in_selection?(buffer, x, y) do
    ScreenBuffer.in_selection?(buffer, x, y)
  end

  @doc """
  Writes a string to the buffer at the given position with the given style.
  """
  @spec write_string(Raxol.Terminal.ScreenBuffer.t(), non_neg_integer(), non_neg_integer(), String.t(), map()) :: Raxol.Terminal.ScreenBuffer.t()
  def write_string(buffer, x, y, string, style) do
    Raxol.Terminal.ScreenBuffer.write_string(buffer, x, y, string, style)
  end
end
