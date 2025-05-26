defmodule Raxol.Terminal.Emulator.Buffer do
  @moduledoc """
  Handles screen buffer management for the terminal emulator.
  Provides functions for buffer operations, scroll region handling, and buffer switching.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    ScreenBuffer,
    Buffer.Manager.Buffer,
    Core,
    Emulator
  }

  @doc """
  Switches between main and alternate screen buffers.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec switch_buffer(Core.t(), :main | :alternate) ::
          {:ok, Core.t()} | {:error, String.t()}
  def switch_buffer(%Core{} = emulator, :main) do
    {:ok, %{emulator | active_buffer_type: :main}}
  end

  def switch_buffer(%Core{} = emulator, :alternate) do
    {:ok, %{emulator | active_buffer_type: :alternate}}
  end

  def switch_buffer(%Core{} = _emulator, invalid_type) do
    {:error, "Invalid buffer type: #{inspect(invalid_type)}"}
  end

  @doc """
  Sets the scroll region for the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec set_scroll_region(Core.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def set_scroll_region(%Core{} = emulator, top, bottom) when top < bottom do
    {:ok, %{emulator | scroll_region: {top, bottom}}}
  end

  def set_scroll_region(%Core{} = _emulator, top, bottom) do
    {:error,
     "Invalid scroll region: top (#{top}) must be less than bottom (#{bottom})"}
  end

  @doc """
  Clears the scroll region, allowing scrolling of the entire screen.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_scroll_region(Core.t()) :: {:ok, Core.t()}
  def clear_scroll_region(%Core{} = emulator) do
    {:ok, %{emulator | scroll_region: nil}}
  end

  @doc """
  Scrolls the active buffer up by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec scroll_up(Core.t(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def scroll_up(%Core{} = emulator, lines) when lines > 0 do
    active_buffer = Emulator.get_active_buffer(emulator)

    case Buffer.scroll_up(active_buffer, lines, emulator.scroll_region) do
      {:ok, updated_buffer} ->
        updated_emulator = update_active_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def scroll_up(%Core{} = _emulator, lines) do
    {:error, "Invalid scroll lines: #{inspect(lines)}"}
  end

  @doc """
  Scrolls the active buffer down by the specified number of lines.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec scroll_down(Core.t(), non_neg_integer()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def scroll_down(%Core{} = emulator, lines) when lines > 0 do
    active_buffer = Emulator.get_active_buffer(emulator)

    case Buffer.scroll_down(active_buffer, lines, emulator.scroll_region) do
      {:ok, updated_buffer} ->
        updated_emulator = update_active_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def scroll_down(%Core{} = _emulator, lines) do
    {:error, "Invalid scroll lines: #{inspect(lines)}"}
  end

  @doc """
  Clears the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_buffer(Core.t()) :: {:ok, Core.t()} | {:error, String.t()}
  def clear_buffer(%Core{} = emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)

    case Buffer.clear(active_buffer) do
      {:ok, updated_buffer} ->
        updated_emulator = update_active_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clears the active buffer from cursor to end of screen.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_from_cursor_to_end(Core.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def clear_from_cursor_to_end(%Core{} = emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)

    case Buffer.clear_from_cursor_to_end(
           active_buffer,
           emulator.cursor
         ) do
      {:ok, updated_buffer} ->
        updated_emulator = update_active_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clears the active buffer from cursor to start of screen.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_from_cursor_to_start(Core.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def clear_from_cursor_to_start(%Core{} = emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)

    case Buffer.clear_from_cursor_to_start(
           active_buffer,
           emulator.cursor
         ) do
      {:ok, updated_buffer} ->
        updated_emulator = update_active_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clears the current line in the active buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec clear_line(Core.t()) :: {:ok, Core.t()} | {:error, String.t()}
  def clear_line(%Core{} = emulator) do
    active_buffer = Emulator.get_active_buffer(emulator)

    case Buffer.clear_line(active_buffer, emulator.cursor) do
      {:ok, updated_buffer} ->
        updated_emulator = update_active_buffer(emulator, updated_buffer)
        {:ok, updated_emulator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper function to update the active buffer in the emulator
  defp update_active_buffer(
         %Core{active_buffer_type: :main} = emulator,
         updated_buffer
       ) do
    %{emulator | main_screen_buffer: updated_buffer}
  end

  defp update_active_buffer(
         %Core{active_buffer_type: :alternate} = emulator,
         updated_buffer
       ) do
    %{emulator | alternate_screen_buffer: updated_buffer}
  end
end
