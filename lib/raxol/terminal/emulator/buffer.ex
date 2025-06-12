defmodule Raxol.Terminal.Emulator.Buffer do
  @moduledoc """
  Handles screen buffer management for the terminal emulator.
  Provides functions for buffer operations, scroll region handling, and buffer switching.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    Commands.Screen,
    Emulator.Struct,
    Buffer
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
  @spec set_scroll_region(EmulatorStruct.t(), non_neg_integer(), non_neg_integer()) ::
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
  Scrolls the active buffer up by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec scroll_up(EmulatorStruct.t(), non_neg_integer()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def scroll_up(%EmulatorStruct{} = emulator, lines) when lines > 0 do
    updated_emulator = Screen.scroll_up(emulator, lines)
    {:ok, updated_emulator}
  end

  def scroll_up(%EmulatorStruct{} = _emulator, lines) do
    {:error, "Invalid scroll lines: #{inspect(lines)}"}
  end

  @doc """
  Scrolls the active buffer down by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec scroll_down(EmulatorStruct.t(), non_neg_integer()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def scroll_down(%EmulatorStruct{} = emulator, lines) when lines > 0 do
    updated_emulator = Screen.scroll_down(emulator, lines)
    {:ok, updated_emulator}
  end

  def scroll_down(%EmulatorStruct{} = _emulator, lines) do
    {:error, "Invalid scroll lines: #{inspect(lines)}"}
  end

  @doc """
  Clears the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_buffer(EmulatorStruct.t()) :: {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def clear_buffer(%EmulatorStruct{} = emulator) do
    updated_emulator = Screen.clear_screen(emulator, 2)
    {:ok, updated_emulator}
  end

  @doc """
  Clears the active buffer from cursor to end of screen.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_from_cursor_to_end(EmulatorStruct.t()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def clear_from_cursor_to_end(%EmulatorStruct{} = emulator) do
    updated_emulator = Screen.clear_screen(emulator, 0)
    {:ok, updated_emulator}
  end

  @doc """
  Clears the active buffer from cursor to start of screen.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_from_cursor_to_start(EmulatorStruct.t()) ::
          {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def clear_from_cursor_to_start(%EmulatorStruct{} = emulator) do
    updated_emulator = Screen.clear_screen(emulator, 1)
    {:ok, updated_emulator}
  end

  @doc """
  Clears the current line in the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_line(EmulatorStruct.t()) :: {:ok, EmulatorStruct.t()} | {:error, String.t()}
  def clear_line(%EmulatorStruct{} = emulator) do
    updated_emulator = Screen.clear_line(emulator, 2)
    {:ok, updated_emulator}
  end
end
