defmodule Raxol.Terminal.BufferManager do
  @moduledoc """
  Manages terminal buffers including main screen, alternate screen, and scrollback.
  This module is responsible for buffer operations, switching, and content management.
  """

  alias Raxol.Terminal.{
    Emulator,
    ScreenBuffer,
    ScrollbackManager
  }
  require Raxol.Core.Runtime.Log

  @doc """
  Initializes the terminal buffers with the given dimensions.
  Returns {:ok, {main_buffer, alternate_buffer}}.
  """
  @spec initialize_buffers(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, {ScreenBuffer.t(), ScreenBuffer.t()}}
  def initialize_buffers(width, height, scrollback_limit) do
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)
    {:ok, {main_buffer, alternate_buffer}}
  end

  @doc """
  Gets the currently active buffer from the emulator.
  Returns the active buffer.
  """
  @spec get_active_buffer(Emulator.t()) :: ScreenBuffer.t()
  def get_active_buffer(%{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_active_buffer(%{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the active buffer in the emulator.
  Returns the updated emulator.
  """
  @spec update_active_buffer(Emulator.t(), ScreenBuffer.t()) :: Emulator.t()
  def update_active_buffer(%{active_buffer_type: :main} = emulator, new_buffer) do
    %{emulator | main_screen_buffer: new_buffer}
  end

  def update_active_buffer(%{active_buffer_type: :alternate} = emulator, new_buffer) do
    %{emulator | alternate_screen_buffer: new_buffer}
  end

  @doc """
  Switches between main and alternate buffers.
  Returns the updated emulator.
  """
  @spec switch_buffer(Emulator.t()) :: Emulator.t()
  def switch_buffer(emulator) do
    new_type = if emulator.active_buffer_type == :main, do: :alternate, else: :main
    %{emulator | active_buffer_type: new_type}
  end

  @doc """
  Gets the current buffer type.
  Returns :main or :alternate.
  """
  @spec get_buffer_type(Emulator.t()) :: :main | :alternate
  def get_buffer_type(emulator) do
    emulator.active_buffer_type
  end

  @doc """
  Sets the buffer type.
  Returns the updated emulator.
  """
  @spec set_buffer_type(Emulator.t(), :main | :alternate) :: Emulator.t()
  def set_buffer_type(emulator, type) when type in [:main, :alternate] do
    %{emulator | active_buffer_type: type}
  end

  @doc """
  Resizes all buffers to the new dimensions.
  Returns the updated emulator.
  """
  @spec resize_buffers(Emulator.t(), non_neg_integer(), non_neg_integer()) :: Emulator.t()
  def resize_buffers(emulator, new_width, new_height) do
    main_buffer = ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)
    alternate_buffer = ScreenBuffer.resize(emulator.alternate_screen_buffer, new_width, new_height)

    %{
      emulator
      | main_screen_buffer: main_buffer,
        alternate_screen_buffer: alternate_buffer,
        width: new_width,
        height: new_height
    }
  end

  @doc """
  Clears the active buffer.
  Returns the updated emulator.
  """
  @spec clear_active_buffer(Emulator.t()) :: Emulator.t()
  def clear_active_buffer(emulator) do
    buffer = get_active_buffer(emulator)
    cleared_buffer = ScreenBuffer.clear(buffer)
    update_active_buffer(emulator, cleared_buffer)
  end

  @doc """
  Scrolls the active buffer up by the specified number of lines.
  Returns the updated emulator.
  """
  @spec scroll_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_up(emulator, lines) do
    buffer = get_active_buffer(emulator)
    {top, bottom} = ScreenBuffer.get_scroll_region(buffer)

    case ScreenBuffer.scroll_up(buffer, lines, top, bottom) do
      {:ok, new_buffer} ->
        update_active_buffer(emulator, new_buffer)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning("Failed to scroll up: #{inspect(reason)}")
        emulator
    end
  end

  @doc """
  Scrolls the active buffer down by the specified number of lines.
  Returns the updated emulator.
  """
  @spec scroll_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_down(emulator, lines) do
    buffer = get_active_buffer(emulator)
    {top, bottom} = ScreenBuffer.get_scroll_region(buffer)

    case ScreenBuffer.scroll_down(buffer, lines, top, bottom) do
      {:ok, new_buffer} ->
        update_active_buffer(emulator, new_buffer)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning("Failed to scroll down: #{inspect(reason)}")
        emulator
    end
  end

  @doc """
  Gets the scrollback buffer.
  Returns the scrollback buffer.
  """
  @spec get_scrollback_buffer(Emulator.t()) :: list()
  def get_scrollback_buffer(emulator) do
    ScrollbackManager.get_scrollback_buffer(emulator)
  end

  @doc """
  Adds a line to the scrollback buffer.
  Returns the updated emulator.
  """
  @spec add_to_scrollback(Emulator.t(), String.t()) :: Emulator.t()
  def add_to_scrollback(emulator, line) do
    ScrollbackManager.add_to_scrollback(emulator, line)
  end

  @doc """
  Clears the scrollback buffer.
  Returns the updated emulator.
  """
  @spec clear_scrollback(Emulator.t()) :: Emulator.t()
  def clear_scrollback(emulator) do
    ScrollbackManager.clear_scrollback(emulator)
  end
end
