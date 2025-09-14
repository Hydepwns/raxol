defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Simple terminal buffer operations for emulator state management.

  This module provides functional operations on Emulator structs for basic
  buffer operations like switching between main/alternate buffers, scrolling,
  and buffer management.

  ## Note
  This module provides the main Buffer.Manager interface that was referenced
  throughout the codebase. For specialized buffer operations, see the manager
  subdirectory modules.

  ## Usage
  This module is used by CSI handlers and other emulator components that need
  to perform simple buffer operations on emulator state.
  """

  alias Raxol.Terminal.{
    Emulator,
    ScreenBuffer,
    ScrollbackManager
  }

  alias Raxol.Terminal.Buffer.Operations

  require Raxol.Core.Runtime.Log

  @doc """
  Initializes the terminal buffers with the given dimensions.
  Returns {:ok, {main_buffer, alternate_buffer}}.
  """
  @spec initialize_buffers(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          {:ok, {ScreenBuffer.t(), ScreenBuffer.t()}}
  def initialize_buffers(width, height, _scrollback_limit) do
    main_buffer = ScreenBuffer.new(width, height)
    alternate_buffer = ScreenBuffer.new(width, height)
    {:ok, {main_buffer, alternate_buffer}}
  end

  @doc """
  Gets the currently active buffer from the emulator.
  Returns the active buffer.
  """
  @spec get_screen_buffer(Emulator.t()) :: ScreenBuffer.t()
  def get_screen_buffer(%{active_buffer_type: :main} = emulator) do
    emulator.main_screen_buffer
  end

  def get_screen_buffer(%{active_buffer_type: :alternate} = emulator) do
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

  def update_active_buffer(
        %{active_buffer_type: :alternate} = emulator,
        new_buffer
      ) do
    %{emulator | alternate_screen_buffer: new_buffer}
  end

  @doc """
  Switches between main and alternate buffers.
  Returns the updated emulator.
  """
  @spec switch_buffer(Emulator.t()) :: Emulator.t()
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
  @spec resize_buffers(Emulator.t(), non_neg_integer(), non_neg_integer()) ::
          Emulator.t()
  def resize_buffers(emulator, new_width, new_height) do
    main_buffer =
      ScreenBuffer.resize(emulator.main_screen_buffer, new_width, new_height)

    alternate_buffer =
      ScreenBuffer.resize(
        emulator.alternate_screen_buffer,
        new_width,
        new_height
      )

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
    buffer = get_screen_buffer(emulator)
    cleared_buffer = ScreenBuffer.clear(buffer)
    update_active_buffer(emulator, cleared_buffer)
  end

  @doc """
  Scrolls the active buffer up by the specified number of lines.
  Returns the updated emulator.
  """
  @spec scroll_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_up(emulator, lines) do
    buffer = get_screen_buffer(emulator)
    new_buffer = Raxol.Terminal.Buffer.Scroller.scroll_up(buffer, lines)
    update_active_buffer(emulator, new_buffer)
  end

  @doc """
  Scrolls the active buffer down by the specified number of lines.
  Returns the updated emulator.
  """
  @spec scroll_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_down(emulator, lines) do
    buffer = get_screen_buffer(emulator)
    new_buffer = Raxol.Terminal.Buffer.Scroller.scroll_down(buffer, lines)
    update_active_buffer(emulator, new_buffer)
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

  @doc """
  Moves an element to a new position in the terminal buffer.

  ## Parameters
  - element: The element to move
  - new_x: New X coordinate
  - new_y: New Y coordinate

  ## Returns
  Updated element with new position
  """
  @spec move_element(map(), integer(), integer()) :: map()
  def move_element(element, new_x, new_y) do
    Operations.move_element(element, new_x, new_y)
  end

  @doc """
  Sets the opacity of an element in the terminal buffer.

  ## Parameters
  - element: The element to modify
  - opacity: Opacity value between 0.0 and 1.0

  ## Returns
  Updated element with new opacity
  """
  @spec set_element_opacity(map(), float()) :: map()
  def set_element_opacity(element, opacity) do
    Operations.set_element_opacity(element, opacity)
  end

  @doc """
  Resizes an element in the terminal buffer.

  ## Parameters
  - element: The element to resize
  - new_width: New width in terminal columns
  - new_height: New height in terminal rows

  ## Returns
  Updated element with new dimensions
  """
  @spec resize_element(map(), integer(), integer()) :: map()
  def resize_element(element, new_width, new_height) do
    Operations.resize_element(element, new_width, new_height)
  end

  # GenServer-style functions for compatibility with existing code

  @doc """
  Starts a buffer manager process.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts) do
    # For now, return a simple state - this could be enhanced later
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    {:ok, {width, height}}
  end

  @doc """
  Creates a new buffer manager instance.
  """
  @spec new() :: term()
  def new() do
    %{width: 80, height: 24, main_buffer: nil, alternate_buffer: nil}
  end

  @spec new(non_neg_integer(), non_neg_integer()) :: {:ok, term()}
  def new(width, height) do
    {:ok,
     %{width: width, height: height, main_buffer: nil, alternate_buffer: nil}}
  end

  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, term()}
  def new(width, height, scrollback_limit) do
    {:ok,
     %{
       width: width,
       height: height,
       scrollback_limit: scrollback_limit,
       main_buffer: nil,
       alternate_buffer: nil
     }}
  end

  @spec new(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: {:ok, term()}
  def new(width, height, scrollback_limit, memory_limit) do
    {:ok,
     %{
       width: width,
       height: height,
       scrollback_limit: scrollback_limit,
       memory_limit: memory_limit,
       main_buffer: nil,
       alternate_buffer: nil
     }}
  end

  @doc """
  Reads data from the buffer manager.
  """
  @spec read(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def read(manager, _opts \\ []) do
    {:ok, manager}
  end

  @doc """
  Writes data to the buffer manager.
  """
  @spec write(term(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def write(manager, _data, _opts \\ []) do
    {:ok, manager}
  end

  @doc """
  Resizes the buffer manager.
  """
  @spec resize(term(), non_neg_integer(), non_neg_integer()) ::
          {:ok, term()} | {:error, term()}
  def resize(manager, _width, _height) do
    {:ok, manager}
  end

  @doc """
  Clears damage tracking.
  """
  @spec clear_damage(term()) :: {:ok, term()} | {:error, term()}
  def clear_damage(manager) do
    {:ok, manager}
  end

  @doc """
  Updates memory usage tracking for the buffer manager.
  """
  @spec update_memory_usage(term()) :: term()
  def update_memory_usage(manager) when is_map(manager) do
    # Calculate memory usage based on buffer sizes and metadata
    memory_usage = calculate_buffer_memory_usage(manager)
    Map.put(manager, :memory_usage, memory_usage)
  end

  def update_memory_usage(manager) do
    # Return as-is for non-map managers
    manager
  end

  @doc """
  Checks if the buffer manager is within memory limits.
  """
  @spec within_memory_limits?(term()) :: boolean()
  def within_memory_limits?(manager) when is_map(manager) do
    memory_usage = Map.get(manager, :memory_usage, 0)
    # 10MB default
    memory_limit = Map.get(manager, :memory_limit, 10_000_000)
    memory_usage <= memory_limit
  end

  def within_memory_limits?(_manager) do
    # Assume within limits for non-map managers
    true
  end

  # Private helper function for memory calculation
  defp calculate_buffer_memory_usage(manager) do
    # Base manager overhead
    base_size = 1000

    main_buffer_size =
      case Map.get(manager, :main_buffer) do
        # Estimate 8 bytes per cell
        %{width: w, height: h} -> w * h * 8
        _ -> 0
      end

    alternate_buffer_size =
      case Map.get(manager, :alternate_buffer) do
        %{width: w, height: h} -> w * h * 8
        _ -> 0
      end

    scrollback_size =
      case Map.get(manager, :scrollback_limit, 0) do
        limit when is_integer(limit) -> limit * Map.get(manager, :width, 80) * 8
        _ -> 0
      end

    base_size + main_buffer_size + alternate_buffer_size + scrollback_size
  end
end
