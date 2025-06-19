defmodule Raxol.Terminal.ScreenManager do
  @moduledoc """
  Manages terminal screen operations including buffer management, resizing, and switching.
  This module is responsible for handling all screen-related operations in the terminal.
  """

  alias Raxol.Terminal.{Emulator, ScreenBuffer}
  require Raxol.Core.Runtime.Log

  @doc """
  Parses the scrollback limit from options.
  Returns the scrollback limit.
  """
  @spec parse_scrollback_limit(map()) :: non_neg_integer()
  def parse_scrollback_limit(opts) do
    opts[:scrollback] ||
      Application.get_env(:raxol, :terminal, %{})[:scrollback_lines] ||
      1000
  end

  @doc """
  Initializes the main and alternate buffers.
  Returns a tuple of {main_buffer, alt_buffer}.
  """
  @spec initialize_buffers(non_neg_integer(), non_neg_integer()) ::
          {ScreenBuffer.t(), ScreenBuffer.t()}
  def initialize_buffers(width, height) do
    main_buffer = ScreenBuffer.new(width, height)
    alt_buffer = ScreenBuffer.new(width, height)
    {main_buffer, alt_buffer}
  end

  @doc """
  Gets the currently active buffer.
  Returns the active screen buffer.
  """
  @spec get_active_buffer(Emulator.t()) :: ScreenBuffer.t()
  def get_active_buffer(%Emulator{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_active_buffer(%Emulator{active_buffer_type: :alternate} = emulator) do
    emulator.alternate_screen_buffer
  end

  @doc """
  Updates the currently active screen buffer.
  Returns the updated emulator.
  """
  @spec update_active_buffer(Emulator.t(), ScreenBuffer.t()) :: Emulator.t()
  def update_active_buffer(%Emulator{active_buffer_type: :main} = emulator, new_buffer) do
    %{emulator | main_screen_buffer: new_buffer}
  end

  def update_active_buffer(%Emulator{active_buffer_type: :alternate} = emulator, new_buffer) do
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
  Resizes both buffers to new dimensions.
  Returns the updated emulator.
  """
  @spec resize_buffers(Emulator.t(), non_neg_integer(), non_neg_integer()) :: Emulator.t()
  def resize_buffers(emulator, new_width, new_height) do
    main_buffer = ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)
    alt_buffer = ScreenBuffer.resize(emulator.alternate_screen_buffer, new_width, new_height)

    %{emulator |
      width: new_width,
      height: new_height,
      main_screen_buffer: main_buffer,
      alternate_screen_buffer: alt_buffer
    }
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
  Creates a new screen buffer with the given dimensions.
  Returns a new screen buffer.
  """
  @spec new_buffer(non_neg_integer(), non_neg_integer()) :: ScreenBuffer.t()
  def new_buffer(width, height) do
    ScreenBuffer.new(width, height)
  end

  @doc """
  Clears the active buffer.
  Returns the updated emulator.
  """
  @spec clear_active_buffer(Emulator.t()) :: Emulator.t()
  def clear_active_buffer(emulator) do
    buffer = get_active_buffer(emulator)
    new_buffer = ScreenBuffer.clear(buffer)
    update_active_buffer(emulator, new_buffer)
  end

  @doc """
  Gets the dimensions of the active buffer.
  Returns {width, height}.
  """
  @spec get_dimensions(Emulator.t()) :: {non_neg_integer(), non_neg_integer()}
  def get_dimensions(emulator) do
    buffer = get_active_buffer(emulator)
    {buffer.width, buffer.height}
  end
end
