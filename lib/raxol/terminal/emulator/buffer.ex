defmodule Raxol.Terminal.Emulator.Buffer do
  @moduledoc """
  Handles screen buffer management for the terminal emulator.
  Provides functions for buffer operations, scroll region handling, and buffer switching.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    Commands.Screen,
    Emulator
  }

  @doc """
  Switches between main and alternate screen buffers.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec switch_buffer(Emulator.t(), :main | :alternate) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def switch_buffer(%Emulator{} = emulator, :main) do
    {:ok, %{emulator | active_buffer_type: :main}}
  end

  def switch_buffer(%Emulator{} = emulator, :alternate) do
    {:ok, %{emulator | active_buffer_type: :alternate}}
  end

  def switch_buffer(%Emulator{} = _emulator, invalid_type) do
    {:error, "Invalid buffer type: #{inspect(invalid_type)}"}
  end

  @doc """
  Sets the scroll region for the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_scroll_region(Emulator.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def set_scroll_region(%Emulator{} = emulator, top, bottom)
      when top < bottom do
    {:ok, %{emulator | scroll_region: {top, bottom}}}
  end

  def set_scroll_region(%Emulator{} = _emulator, top, bottom) do
    {:error,
     "Invalid scroll region: top (#{top}) must be less than bottom (#{bottom})"}
  end

  @doc """
  Clears the scroll region, allowing scrolling of the entire screen.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_scroll_region(Emulator.t()) :: {:ok, Emulator.t()}
  def clear_scroll_region(%Emulator{} = emulator) do
    {:ok, %{emulator | scroll_region: nil}}
  end

  @doc """
  Scrolls the active buffer up by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec scroll_up(Emulator.t(), non_neg_integer()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def scroll_up(%Emulator{} = emulator, lines) when lines > 0 do
    updated_emulator = Screen.scroll_up(emulator, lines)
    {:ok, updated_emulator}
  end

  def scroll_up(%Emulator{} = _emulator, lines) do
    {:error, "Invalid scroll lines: #{inspect(lines)}"}
  end

  @doc """
  Scrolls the active buffer down by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec scroll_down(Emulator.t(), non_neg_integer()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def scroll_down(%Emulator{} = emulator, lines) when lines > 0 do
    updated_emulator = Screen.scroll_down(emulator, lines)
    {:ok, updated_emulator}
  end

  def scroll_down(%Emulator{} = _emulator, lines) do
    {:error, "Invalid scroll lines: #{inspect(lines)}"}
  end

  @doc """
  Clears the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_buffer(Emulator.t()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def clear_buffer(%Emulator{} = emulator) do
    updated_emulator = Screen.clear_screen(emulator, 2)
    {:ok, updated_emulator}
  end

  @doc """
  Clears the active buffer from cursor to end of screen.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_from_cursor_to_end(Emulator.t()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def clear_from_cursor_to_end(%Emulator{} = emulator) do
    updated_emulator = Screen.clear_screen(emulator, 0)
    {:ok, updated_emulator}
  end

  @doc """
  Clears the active buffer from cursor to start of screen.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_from_cursor_to_start(Emulator.t()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def clear_from_cursor_to_start(%Emulator{} = emulator) do
    updated_emulator = Screen.clear_screen(emulator, 1)
    {:ok, updated_emulator}
  end

  @doc """
  Clears the current line in the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_line(Emulator.t()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def clear_line(%Emulator{} = emulator) do
    updated_emulator = Screen.clear_line(emulator, 2)
    {:ok, updated_emulator}
  end
end
