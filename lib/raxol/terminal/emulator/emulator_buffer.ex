defmodule Raxol.Terminal.Emulator.Buffer do
  @moduledoc """
  Provides buffer management functionality for the terminal emulator.
  """

  alias Raxol.Terminal.{
    ScreenBuffer
  }

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct

  @doc """
  Switches between main and alternate screen buffers.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec switch_buffer(EmulatorStruct.t(), :main | :alternate) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def switch_buffer(%EmulatorStruct{} = emulator, :main) do
    {:ok, %{emulator | active_buffer_type: :main}}
  end

  def switch_buffer(%EmulatorStruct{} = emulator, :alternate) do
    {:ok, %{emulator | active_buffer_type: :alternate}}
  end

  def switch_buffer(%EmulatorStruct{} = _emulator, invalid_type) do
    {:error, "Invalid buffer type: #{inspect(invalid_type)}"}
  end

  @doc """
  Sets the scroll region for the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_scroll_region(
          EmulatorStruct.t(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def set_scroll_region(%EmulatorStruct{} = emulator, top, bottom)
      when top < bottom do
    {:ok, %{emulator | scroll_region: {top, bottom}}}
  end

  def set_scroll_region(%EmulatorStruct{} = _emulator, top, bottom) do
    {:error,
     "Invalid scroll region: top (#{top}) must be less than bottom (#{bottom})"}
  end

  @doc """
  Clears the scroll region, allowing scrolling of the entire screen.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_scroll_region(EmulatorStruct.t()) :: {:ok, EmulatorStruct.t()}
  def clear_scroll_region(%EmulatorStruct{} = emulator) do
    {:ok, %{emulator | scroll_region: nil}}
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up_emulator(emulator, lines) do
    {updated_emulator, _scrolled_lines} =
      ScreenBuffer.scroll_up(emulator, lines)

    %{updated_emulator | active_buffer: updated_emulator.active_buffer}
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(emulator, lines) do
    updated_emulator = ScreenBuffer.scroll_down(emulator, lines)
    %{updated_emulator | active_buffer: updated_emulator.active_buffer}
  end

  @doc """
  Clears the entire buffer.
  """
  def clear_buffer(emulator) do
    updated_emulator = ScreenBuffer.clear(emulator)
    %{updated_emulator | cursor: %{updated_emulator.cursor | x: 0, y: 0}}
  end

  @doc """
  Clears from cursor to end of screen.
  """
  def clear_from_cursor_to_end(emulator) do
    updated_emulator = ScreenBuffer.clear(emulator)
    %{updated_emulator | cursor: %{updated_emulator.cursor | x: 0}}
  end

  @doc """
  Clears from start of screen to cursor.
  """
  def clear_from_cursor_to_start(emulator) do
    updated_emulator = ScreenBuffer.clear(emulator)
    %{updated_emulator | cursor: %{updated_emulator.cursor | x: 0}}
  end

  @doc """
  Clears the current line.
  """
  def clear_line(emulator) do
    ScreenBuffer.clear_line(emulator, 2)
  end
end
