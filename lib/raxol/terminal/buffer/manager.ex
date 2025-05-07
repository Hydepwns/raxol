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
  alias Raxol.Terminal.Buffer.DamageTracker
  alias Raxol.Terminal.Buffer.Scrollback
  alias Raxol.Terminal.Buffer.MemoryManager
  alias Raxol.Terminal.ANSI.TextFormatting

  @type t :: %__MODULE__{
          active_buffer: ScreenBuffer.t(),
          back_buffer: ScreenBuffer.t(),
          damage_tracker: DamageTracker.t(),
          memory_limit: non_neg_integer(),
          memory_usage: non_neg_integer(),
          cursor_position: {non_neg_integer(), non_neg_integer()},
          scrollback: Scrollback.t()
        }

  defstruct [
    :active_buffer,
    :back_buffer,
    :damage_tracker,
    :memory_limit,
    :memory_usage,
    :cursor_position,
    :scrollback
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

    new(width, height, scrollback_height, memory_limit)
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

    {:ok,
     %__MODULE__{
       active_buffer: active_buffer,
       back_buffer: back_buffer,
       damage_tracker: DamageTracker.new(),
       memory_limit: memory_limit,
       memory_usage: 0,
       cursor_position: {0, 0},
       scrollback: Scrollback.new(scrollback_height)
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
    %{
      manager
      | active_buffer: manager.back_buffer,
        back_buffer: manager.active_buffer,
        damage_tracker: DamageTracker.clear_regions(manager.damage_tracker)
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
    new_tracker = DamageTracker.mark_damaged(manager.damage_tracker, x1, y1, x2, y2)
    %{manager | damage_tracker: new_tracker}
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
    DamageTracker.get_regions(manager.damage_tracker)
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
    new_tracker = DamageTracker.clear_regions(manager.damage_tracker)
    %{manager | damage_tracker: new_tracker}
  end

  @doc """
  Updates memory usage tracking.
  Delegates calculation to `MemoryManager.get_total_usage/2`.
  """
  def update_memory_usage(%__MODULE__{} = manager) do
    total_usage = MemoryManager.get_total_usage(manager.active_buffer, manager.back_buffer)
    %{manager | memory_usage: total_usage}
  end

  @doc """
  Checks if memory usage is within limits.
  Delegates check to `MemoryManager.is_within_limit?/2`.
  """
  def within_memory_limits?(%__MODULE__{} = manager) do
    MemoryManager.is_within_limit?(manager.memory_usage, manager.memory_limit)
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
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec erase_from_beginning_to_cursor(t(), TextFormatting.text_style()) :: t()
  def erase_from_beginning_to_cursor(%__MODULE__{} = manager, default_style) do
    {x, y} = manager.cursor_position

    # Call ScreenBuffer function (which uses Eraser)
    new_active_buffer =
      ScreenBuffer.erase_in_display(manager.active_buffer, {x,y}, :to_beginning, default_style)

    # Determine damage region (assuming erase returns the buffer)
    # TODO: Refine damage tracking if erase functions no longer return region
    {cx1, cy1, cx2, cy2} = {0, 0, x, y} # Approximate damage

    # Mark the region as damaged
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Update the active buffer state
    %{manager_with_damage | active_buffer: new_active_buffer}
  end

  @doc """
  Clears the visible portion of the display (viewport) without affecting the scrollback buffer.
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec clear_visible_display(t(), TextFormatting.text_style()) :: t()
  def clear_visible_display(%__MODULE__{active_buffer: buffer} = manager, default_style) do
    # Call ScreenBuffer.clear (which uses Eraser.clear_screen)
    new_active_buffer = ScreenBuffer.clear(buffer, default_style)

    # Determine damage region
    {cx1, cy1, cx2, cy2} = {0, 0, ScreenBuffer.get_width(buffer) - 1, ScreenBuffer.get_height(buffer) - 1}

    # Mark the entire visible region as damaged (using region from clear)
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Update the active buffer state
    %{manager_with_damage | active_buffer: new_active_buffer}
  end

  @doc """
  Clears the entire display including the scrollback buffer.
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec clear_entire_display_with_scrollback(t(), TextFormatting.text_style()) :: t()
  def clear_entire_display_with_scrollback(%__MODULE__{} = manager, default_style) do
    # Clear the active buffer cells
    new_active_buffer = ScreenBuffer.clear(manager.active_buffer, default_style)

    # Determine damage region
    {buffer_width, buffer_height} = ScreenBuffer.get_dimensions(new_active_buffer)
    {cx1, cy1, cx2, cy2} = {0, 0, buffer_width - 1, buffer_height - 1}

    # Mark the region as damaged
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Clear the scrollback state
    new_scrollback = Scrollback.clear(manager.scrollback)

    %{manager_with_damage | active_buffer: new_active_buffer, scrollback: new_scrollback}
  end

  @doc """
  Erases from the cursor to the end of the current line.
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec erase_from_cursor_to_end_of_line(t(), TextFormatting.text_style()) :: t()
  def erase_from_cursor_to_end_of_line(%__MODULE__{} = manager, default_style) do
    {x, y} = manager.cursor_position
    buffer_width = ScreenBuffer.get_width(manager.active_buffer)

    # Call ScreenBuffer function
    new_active_buffer =
      ScreenBuffer.erase_in_line(manager.active_buffer, {x,y}, :to_end, default_style)

    # Determine damage region
    {cx1, cy1, cx2, cy2} = {x, y, buffer_width - 1, y} # Approximate damage

    # Mark the region as damaged
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Update the active buffer state
    %{manager_with_damage | active_buffer: new_active_buffer}
  end

  @doc """
  Erases from the beginning of the current line to the cursor position.
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec erase_from_beginning_of_line_to_cursor(t(), TextFormatting.text_style()) :: t()
  def erase_from_beginning_of_line_to_cursor(%__MODULE__{} = manager, default_style) do
    {x, y} = manager.cursor_position

    # Call ScreenBuffer function
    new_active_buffer =
      ScreenBuffer.erase_in_line(manager.active_buffer, {x,y}, :to_beginning, default_style)

    # Determine damage region
    {cx1, cy1, cx2, cy2} = {0, y, x, y} # Approximate damage

    # Mark the region as damaged
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Update the active buffer state
    %{manager_with_damage | active_buffer: new_active_buffer}
  end

  @doc """
  Clears the entire current line where the cursor is located.
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec clear_current_line(t(), TextFormatting.text_style()) :: t()
  def clear_current_line(%__MODULE__{} = manager, default_style) do
    {x, y} = manager.cursor_position
    buffer_width = ScreenBuffer.get_width(manager.active_buffer)

    # Call ScreenBuffer function
    new_active_buffer =
      ScreenBuffer.erase_in_line(manager.active_buffer, {x,y}, :all, default_style)

    # Determine damage region
    {cx1, cy1, cx2, cy2} = {0, y, buffer_width - 1, y} # Approximate damage

    # Mark the region as damaged
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Update the active buffer state
    %{manager_with_damage | active_buffer: new_active_buffer}
  end

  @doc """
  Erases from the cursor position to the end of the display.
  Marks the cleared region as damaged.
  Requires the default_style to use for clearing.
  """
  @spec erase_from_cursor_to_end(t(), TextFormatting.text_style()) :: t()
  def erase_from_cursor_to_end(%__MODULE__{} = manager, default_style) do
    {x, y} = manager.cursor_position
    {buffer_width, buffer_height} = ScreenBuffer.get_dimensions(manager.active_buffer)

    # Call ScreenBuffer function (which uses Eraser)
    new_active_buffer =
      ScreenBuffer.erase_in_display(manager.active_buffer, {x,y}, :to_end, default_style)

    # Determine damage region
    {cx1, cy1, cx2, cy2} = {x, y, buffer_width - 1, buffer_height - 1} # Approximate damage

    # Mark the region as damaged
    manager_with_damage = mark_damaged(manager, cx1, cy1, cx2, cy2)

    # Update the active buffer state
    %{manager_with_damage | active_buffer: new_active_buffer}
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  Lines that scroll off the top are added to the scrollback buffer.
  """
  def scroll_up(manager, lines) do
    # Call modified ScreenBuffer.scroll_up (which delegates to Operations.scroll_up)
    # It now returns {updated_cells, scrolled_off_lines}
    {updated_cells, scrolled_off_lines} = ScreenBuffer.scroll_up(manager.active_buffer, lines)

    # Add scrolled lines to our scrollback state
    new_scrollback = Scrollback.add_lines(manager.scrollback, scrolled_off_lines)

    # Update manager state
    %{
      manager
      | active_buffer: %{manager.active_buffer | cells: updated_cells},
        scrollback: new_scrollback
    }
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  Lines are restored from the scrollback buffer if available.
  """
  def scroll_down(manager, lines) do
    # Take lines from our scrollback state
    {lines_to_restore, new_scrollback} = Scrollback.take_lines(manager.scrollback, lines)

    # Call modified ScreenBuffer.scroll_down (delegating to Operations.scroll_down)
    # passing the lines to insert
    updated_active_buffer = ScreenBuffer.scroll_down(manager.active_buffer, lines_to_restore, lines)

    # Update manager state
    %{
      manager
      | active_buffer: updated_active_buffer,
        scrollback: new_scrollback
    }
  end

  @doc """
  Sets a scroll region in the buffer. All scrolling operations will be confined to this region.
  The region is specified by start and end line numbers (inclusive).
  """
  def set_scroll_region(manager, start_line, end_line) do
    active_buffer =
      ScreenBuffer.set_scroll_region(
        manager.active_buffer,
        start_line,
        end_line
      )

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
  def in_selection?(manager, x, y) do
    ScreenBuffer.in_selection?(manager.active_buffer, x, y)
  end

  # For backward compatibility
  @doc false
  @deprecated "Use in_selection?/2 instead"
  def is_in_selection?(manager, x, y), do: in_selection?(manager, x, y)

  @doc """
  Gets the boundaries of the current selection.
  Returns nil if there is no selection.
  """
  def get_selection_boundaries(manager) do
    ScreenBuffer.get_selection_boundaries(manager.active_buffer)
  end

end
