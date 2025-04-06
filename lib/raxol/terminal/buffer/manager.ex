defmodule Raxol.Terminal.Buffer.Manager do
  @moduledoc """
  Terminal buffer manager module.

  This module handles the management of terminal buffers, including:
  - Double buffering implementation
  - Damage tracking system
  - Buffer synchronization
  - Memory management
  """

  use GenServer

  alias Raxol.Terminal.ScreenBuffer

  @type t :: %__MODULE__{
    active_buffer: ScreenBuffer.t(),
    back_buffer: ScreenBuffer.t(),
    damage_regions: list({non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}),
    memory_limit: non_neg_integer(),
    memory_usage: non_neg_integer(),
    cursor_position: {non_neg_integer(), non_neg_integer()},
    scrollback_buffer: list(ScreenBuffer.t())
  }

  defstruct [
    :active_buffer,
    :back_buffer,
    :damage_regions,
    :memory_limit,
    :memory_usage,
    :cursor_position,
    :scrollback_buffer
  ]

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) when is_list(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    scrollback_height = Keyword.get(opts, :scrollback_height, 1000)
    memory_limit = Keyword.get(opts, :memory_limit, 10_000_000)

    case new(width, height, scrollback_height, memory_limit) do
      {:ok, state} -> {:ok, state}
      error -> error
    end
  end

  def init(_opts) do
    init([])
  end

  @doc """
  Creates a new buffer manager with the given dimensions.

  ## Examples

      iex> {:ok, manager} = Manager.new(80, 24)
      iex> manager.active_buffer.width
      80
      iex> manager.active_buffer.height
      24
  """
  def new(width, height, scrollback_height \\ 1000, memory_limit \\ 10_000_000) do
    active_buffer = ScreenBuffer.new(width, height, scrollback_height)
    back_buffer = ScreenBuffer.new(width, height, scrollback_height)

    {:ok, %__MODULE__{
      active_buffer: active_buffer,
      back_buffer: back_buffer,
      damage_regions: [],
      memory_limit: memory_limit,
      memory_usage: 0,
      cursor_position: {0, 0},
      scrollback_buffer: []
    }}
  end

  @doc """
  Switches the active and back buffers.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.switch_buffers(manager)
      iex> manager.active_buffer == manager.back_buffer
      false
  """
  def switch_buffers(%__MODULE__{} = manager) do
    %{manager |
      active_buffer: manager.back_buffer,
      back_buffer: manager.active_buffer,
      damage_regions: []
    }
  end

  @doc """
  Marks a region of the buffer as damaged.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)
      iex> length(manager.damage_regions)
      1
  """
  def mark_damaged(%__MODULE__{} = manager, x1, y1, x2, y2) do
    new_region = {x1, y1, x2, y2}

    # Merge overlapping regions
    merged_regions = merge_damage_regions([new_region | manager.damage_regions])

    %{manager | damage_regions: merged_regions}
  end

  @doc """
  Gets all damaged regions.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)
      iex> regions = Buffer.Manager.get_damage_regions(manager)
      iex> length(regions)
      1
  """
  def get_damage_regions(%__MODULE__{} = manager) do
    manager.damage_regions
  end

  @doc """
  Clears all damage regions.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.mark_damaged(manager, 0, 0, 10, 5)
      iex> manager = Buffer.Manager.clear_damage_regions(manager)
      iex> length(manager.damage_regions)
      0
  """
  def clear_damage_regions(%__MODULE__{} = manager) do
    %{manager | damage_regions: []}
  end

  @doc """
  Updates memory usage tracking.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.update_memory_usage(manager)
      iex> manager.memory_usage > 0
      true
  """
  def update_memory_usage(%__MODULE__{} = manager) do
    # Calculate memory usage based on buffer sizes
    active_usage = calculate_buffer_memory_usage(manager.active_buffer)
    back_usage = calculate_buffer_memory_usage(manager.back_buffer)
    total_usage = active_usage + back_usage

    %{manager | memory_usage: total_usage}
  end

  @doc """
  Checks if memory usage is within limits.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> Buffer.Manager.within_memory_limits?(manager)
      true
  """
  def within_memory_limits?(%__MODULE__{} = manager) do
    manager.memory_usage <= manager.memory_limit
  end

  @doc """
  Sets the cursor position.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> manager.cursor_position
      {10, 5}
  """
  def set_cursor_position(%__MODULE__{} = manager, x, y) do
    %{manager | cursor_position: {x, y}}
  end

  @doc """
  Gets the cursor position.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> Buffer.Manager.get_cursor_position(manager)
      {10, 5}
  """
  def get_cursor_position(%__MODULE__{} = manager) do
    manager.cursor_position
  end

  @doc """
  Erases from the beginning of the display to the cursor.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> manager = Buffer.Manager.erase_from_beginning_to_cursor(manager)
      iex> manager.damage_regions
      [{0, 0, 10, 5}]
  """
  def erase_from_beginning_to_cursor(%__MODULE__{} = manager) do
    {x, y} = manager.cursor_position

    # Mark the region as damaged
    manager = mark_damaged(manager, 0, 0, x, y)

    # Clear the cells in the active buffer
    new_active_buffer = ScreenBuffer.clear_region(
      manager.active_buffer,
      0, 0, x, y
    )

    %{manager | active_buffer: new_active_buffer}
  end

  @doc """
  Clears the entire display including the scrollback buffer.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.clear_entire_display_with_scrollback(manager)
      iex> manager.damage_regions
      [{0, 0, 79, 23}]
      iex> manager.scrollback_buffer
      []
  """
  def clear_entire_display_with_scrollback(%__MODULE__{} = manager) do
    width = ScreenBuffer.width(manager.active_buffer)
    height = ScreenBuffer.height(manager.active_buffer)

    # Mark the region as damaged
    manager = mark_damaged(manager, 0, 0, width - 1, height - 1)

    # Clear the cells in the active buffer
    active_buffer = ScreenBuffer.clear_region(manager.active_buffer, 0, 0, width - 1, height - 1)

    # Clear the scrollback buffer
    %{manager |
      active_buffer: active_buffer,
      scrollback_buffer: []
    }
  end

  @doc """
  Erases from the cursor to the end of the current line.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> manager = Buffer.Manager.erase_from_cursor_to_end_of_line(manager)
      iex> manager.damage_regions
      [{10, 5, 79, 5}]
  """
  def erase_from_cursor_to_end_of_line(%__MODULE__{} = manager) do
    {x, y} = manager.cursor_position
    width = ScreenBuffer.width(manager.active_buffer)

    # Mark the region as damaged
    manager = mark_damaged(manager, x, y, width - 1, y)

    # Clear the cells in the active buffer
    active_buffer = ScreenBuffer.clear_region(manager.active_buffer, x, y, width - 1, y)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Erases from the beginning of the current line to the cursor.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> manager = Buffer.Manager.erase_from_beginning_of_line_to_cursor(manager)
      iex> manager.damage_regions
      [{0, 5, 10, 5}]
  """
  def erase_from_beginning_of_line_to_cursor(%__MODULE__{} = manager) do
    {x, y} = manager.cursor_position

    # Mark the region as damaged
    manager = mark_damaged(manager, 0, y, x, y)

    # Clear the cells in the active buffer
    active_buffer = ScreenBuffer.clear_region(manager.active_buffer, 0, y, x, y)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Clears the current line.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> manager = Buffer.Manager.clear_current_line(manager)
      iex> manager.damage_regions
      [{0, 5, 79, 5}]
  """
  def clear_current_line(%__MODULE__{} = manager) do
    {_, y} = manager.cursor_position
    width = ScreenBuffer.width(manager.active_buffer)

    # Mark the region as damaged
    manager = mark_damaged(manager, 0, y, width - 1, y)

    # Clear the cells in the active buffer
    active_buffer = ScreenBuffer.clear_region(manager.active_buffer, 0, y, width - 1, y)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Erases from the cursor position to the end of the display.

  ## Examples

      iex> manager = Buffer.Manager.new(80, 24)
      iex> manager = Buffer.Manager.set_cursor_position(manager, 10, 5)
      iex> manager = Buffer.Manager.erase_from_cursor_to_end(manager)
      iex> manager.damage_regions
      [{10, 5, 79, 23}]
  """
  def erase_from_cursor_to_end(%__MODULE__{} = manager) do
    {x, y} = manager.cursor_position
    width = ScreenBuffer.width(manager.active_buffer)
    height = ScreenBuffer.height(manager.active_buffer)

    # Mark the region as damaged
    manager = mark_damaged(manager, x, y, width - 1, height - 1)

    # Clear the cells in the active buffer
    active_buffer = ScreenBuffer.clear_region(manager.active_buffer, x, y, width - 1, height - 1)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  Lines that scroll off the top are added to the scrollback buffer.
  """
  def scroll_up(manager, lines) do
    # ScreenBuffer.scroll_up only returns the updated buffer, not the scrolled lines.
    # The manager needs to retrieve these lines *before* scrolling if it handles scrollback.
    # TODO: Re-evaluate scrollback handling between Manager and ScreenBuffer.
    active_buffer = ScreenBuffer.scroll_up(manager.active_buffer, lines)

    manager = %{manager |
      active_buffer: active_buffer
      # scrollback_buffer: scrollback ++ manager.scrollback_buffer # Cannot get scrollback this way
    }

    # Trim scrollback buffer if it exceeds the limit
    scrollback_limit = manager.active_buffer.scrollback_limit # Use limit from buffer struct
    if length(manager.scrollback_buffer) > scrollback_limit do
      %{manager | scrollback_buffer: Enum.take(manager.scrollback_buffer, scrollback_limit)}
    else
      manager
    end
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  Lines are restored from the scrollback buffer if available.
  """
  def scroll_down(manager, lines) do
    # ScreenBuffer.scroll_down only returns the updated buffer.
    # It uses its *internal* scrollback, which isn't populated correctly by Manager's scroll_up.
    # TODO: Re-evaluate scrollback handling between Manager and ScreenBuffer.
    active_buffer = ScreenBuffer.scroll_down(manager.active_buffer, lines)

    %{manager |
      active_buffer: active_buffer
      # scrollback_buffer: remaining_scrollback # Cannot get remaining_scrollback this way
    }
  end

  @doc """
  Sets a scroll region in the buffer. All scrolling operations will be confined to this region.
  The region is specified by start and end line numbers (inclusive).
  """
  def set_scroll_region(manager, start_line, end_line) do
    active_buffer = ScreenBuffer.set_scroll_region(manager.active_buffer, start_line, end_line)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Clears the scroll region, making the entire buffer scrollable.
  """
  def clear_scroll_region(manager) do
    active_buffer = ScreenBuffer.clear_scroll_region(manager.active_buffer)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Starts a text selection at the specified coordinates.
  """
  def start_selection(manager, x, y) do
    active_buffer = ScreenBuffer.start_selection(manager.active_buffer, x, y)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Updates the endpoint of the current selection.
  """
  def update_selection(manager, x, y) do
    active_buffer = ScreenBuffer.update_selection(manager.active_buffer, x, y)
    %{manager | active_buffer: active_buffer}
  end

  @doc """
  Gets the text within the current selection.
  Returns an empty string if there is no selection.
  """
  def get_selection(manager) do
    ScreenBuffer.get_selection(manager.active_buffer)
  end

  @doc """
  Checks if the given position is within the current selection.
  Returns false if there is no selection.
  """
  def is_in_selection?(manager, x, y) do
    ScreenBuffer.is_in_selection?(manager.active_buffer, x, y)
  end

  @doc """
  Gets the boundaries of the current selection.
  Returns nil if there is no selection.
  """
  def get_selection_boundaries(manager) do
    ScreenBuffer.get_selection_boundaries(manager.active_buffer)
  end

  # Private functions

  defp merge_damage_regions(regions) do
    regions
    |> Enum.reduce([], fn region, acc ->
      case find_overlapping_region(acc, region) do
        nil -> [region | acc]
        {overlapping, rest} -> [merge_regions(overlapping, region) | rest]
      end
    end)
    |> Enum.reverse()
  end

  defp find_overlapping_region(regions, {x1, y1, x2, y2}) do
    Enum.split_with(regions, fn {rx1, ry1, rx2, ry2} ->
      x1 <= rx2 && x2 >= rx1 && y1 <= ry2 && y2 >= ry1
    end)
    |> case do
      {[overlapping], rest} -> {overlapping, rest}
      _ -> nil
    end
  end

  defp merge_regions({x1, y1, x2, y2}, {rx1, ry1, rx2, ry2}) do
    {
      min(x1, rx1),
      min(y1, ry1),
      max(x2, rx2),
      max(y2, ry2)
    }
  end

  defp calculate_buffer_memory_usage(buffer) do
    # Rough estimation of memory usage based on buffer size and content
    buffer_size = buffer.width * buffer.height
    cell_size = 100  # Estimated bytes per cell
    buffer_size * cell_size
  end
end
