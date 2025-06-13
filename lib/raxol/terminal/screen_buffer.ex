defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Manages the terminal's screen buffer state (grid, scrollback, selection).
  This module serves as the main interface for terminal buffer operations,
  delegating specific operations to specialized modules in Raxol.Terminal.Buffer.*.

  ## Structure

  The buffer consists of:
  * A main grid of cells (the visible screen)
  * A scrollback buffer for history
  * Selection state
  * Scroll region settings
  * Dimensions (width and height)

  ## Operations

  The module delegates operations to specialized modules:
  * `Content` - Writing and content management
  * `ScrollRegion` - Scroll region and scrolling operations
  * `LineOperations` - Line manipulation
  * `CharEditor` - Character editing
  * `LineEditor` - Line editing
  * `Eraser` - Clearing operations
  * `Selection` - Text selection
  * `Scrollback` - History management
  * `Queries` - State querying
  * `Initializer` - Buffer creation and validation

  ## Usage

  ```elixir
  # Create a new buffer
  buffer = ScreenBuffer.new(80, 24)

  # Write some text
  buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello, World!")

  # Get content
  content = ScreenBuffer.get_content(buffer)
  ```

  ## Related Functions

  Common operation patterns:

  * Writing and Reading:
    - `write_char/5` and `write_string/4` for writing content
    - `get_char/3` and `get_content/1` for reading content
    - `get_cell/3` and `get_line/2` for accessing raw buffer data

  * Selection:
    - `start_selection/3` to begin a selection
    - `update_selection/3` to modify the selection
    - `get_selection/1` to get selected text
    - `in_selection?/3` to check if a position is selected

  * Scrolling:
    - `scroll_up/3` and `scroll_down/3` for scrolling content
    - `set_scroll_region/3` to define scroll boundaries
    - `clear_scroll_region/1` to reset scroll region

  * Line Operations:
    - `insert_lines/4` to add new lines
    - `delete_lines/5` to remove lines
    - `prepend_lines/2` to add lines at the top
    - `pop_top_lines/2` to remove lines from the top

  * Character Operations:
    - `insert_characters/5` to add characters
    - `delete_characters/5` to remove characters

  * Clearing:
    - `clear/2` to clear the entire screen
    - `clear_region/6` to clear a specific region
    - `erase_in_display/4` and `erase_in_line/4` for ANSI-style erasing
  """

  @behaviour Raxol.Terminal.ScreenBufferBehaviour

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Selection
  alias Raxol.Terminal.Buffer.Scrollback
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.Buffer.LineEditor
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Buffer.LineOperations
  alias Raxol.Terminal.Buffer.Initializer
  alias Raxol.Terminal.Buffer.Queries
  alias Raxol.Terminal.Buffer.Content
  alias Raxol.Terminal.Buffer.ScrollRegion

  defstruct [
    # The main grid of cells
    :cells,
    :scrollback,
    :scrollback_limit,
    :selection,
    :scroll_region,
    :width,
    :height,
    :cursor_position,
    :damage_regions,
    :default_style
  ]

  @type t :: %__MODULE__{
          cells: list(list(Cell.t())),
          scrollback: list(list(Cell.t())),
          scrollback_limit: non_neg_integer(),
          selection: {integer(), integer(), integer(), integer()} | nil,
          scroll_region: {integer(), integer()} | nil,
          width: non_neg_integer(),
          height: non_neg_integer(),
          cursor_position: {non_neg_integer(), non_neg_integer()},
          damage_regions: [{non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}],
          default_style: TextFormatting.text_style()
        }

  @impl true
  defdelegate new(width, height, scrollback_limit \\ 1000), to: Initializer

  # Header functions for default values
  @impl true
  def write_char(buffer, x, y, char), do: write_char(buffer, x, y, char, nil)
  @impl true
  def write_string(buffer, x, y, string), do: write_string(buffer, x, y, string, nil)

  # Header function for default value
  @impl true
  def clear_line(buffer, line), do: clear_line(buffer, line, nil)

  # Implementation functions without defaults
  @impl true
  defdelegate write_char(buffer, x, y, char, style), to: Content
  @impl true
  def write_string(buffer, x, y, string, style) do
    Content.write_string(buffer, x, y, string, style)
  end

  @impl true
  defdelegate get_char(buffer, x, y), to: Content

  @impl true
  defdelegate get_cell(buffer, x, y), to: Content

  @impl true
  defdelegate clear(buffer, style \\ nil), to: Eraser

  @impl true
  defdelegate clear_line(buffer, line, style), to: Eraser

  @impl true
  defdelegate insert_lines(buffer, count), to: LineOperations

  @impl true
  defdelegate delete_lines(buffer, count), to: LineOperations

  @impl true
  defdelegate insert_chars(buffer, count), to: CharEditor

  @impl true
  defdelegate delete_chars(buffer, count), to: CharEditor

  @impl true
  defdelegate erase_chars(buffer, count), to: CharEditor

  @impl true
  defdelegate scroll_up(buffer, count), to: ScrollRegion

  @impl true
  defdelegate scroll_down(buffer, count), to: ScrollRegion

  @impl true
  defdelegate get_dimensions(buffer), to: Queries

  @impl true
  defdelegate get_width(buffer), to: Queries

  @impl true
  defdelegate get_height(buffer), to: Queries

  @impl true
  defdelegate get_line(buffer, line_index), to: Queries

  @impl true
  defdelegate get_cell_at(buffer, x, y), to: Queries

  # === Delegated Functions ===

  # --- Writing --- (Delegated to Content)
  @doc """
  Writes a character at the specified position with optional styling.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The x-coordinate (column)
  * `y` - The y-coordinate (row)
  * `char` - The character to write
  * `style` - Optional text styling

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_char(buffer, 0, 0, "A", %{bold: true})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      "A"

  ## Related Functions

  * `write_string/4` - To write multiple characters
  * `get_char/3` - To read a character
  * `get_cell/3` - To get the full cell data including style
  * `clear_region/6` - To clear characters
  * `delete_characters/5` - To remove characters
  """
  @spec write_char(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: t()
  defdelegate write_char(buffer, x, y, char, style \\ nil), to: Content

  @doc """
  Writes a string starting at the specified position with optional styling.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The x-coordinate (column) to start writing
  * `y` - The y-coordinate (row) to start writing
  * `string` - The string to write
  * `style` - Optional text styling

  ## Returns

  The updated screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello", %{bold: true})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      "H"

  ## Related Functions

  * `write_char/5` - To write a single character
  * `get_char/3` - To read a character
  * `get_cell/3` - To get the full cell data including style
  * `clear_region/6` - To clear characters
  * `delete_characters/5` - To remove characters
  """
  @spec write_string(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: t()
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write_string(buffer, x, y, string, style \\ nil) do
    Content.write_string(buffer, x, y, string, style)
  end

  # --- Scrolling --- (Delegated to ScrollRegion)
  @doc """
  Scrolls the screen up by the specified number of lines.
  """
  def scroll_up(buffer, lines) do
    Raxol.Terminal.Buffer.Operations.scroll_up(buffer, lines)
  end

  @doc """
  Scrolls the screen down by the specified number of lines.
  """
  def scroll_down(buffer, lines) do
    Raxol.Terminal.Buffer.Operations.scroll_down(buffer, [], lines)
  end

  # --- Scroll Region --- (Delegated to ScrollRegion)
  @doc """
  Sets the scroll region boundaries.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `start_line` - The starting line of the scroll region
  * `end_line` - The ending line of the scroll region

  ## Returns

  The updated screen buffer with new scroll region boundaries.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_scroll_region(buffer, 5, 15)
      iex> ScreenBuffer.get_scroll_region_boundaries(buffer)
      {5, 15}
  """
  @spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate set_scroll_region(buffer, start_line, end_line), to: ScrollRegion, as: :set_region

  @doc """
  Clears the current scroll region, resetting to full screen.

  ## Parameters

  * `buffer` - The screen buffer to modify

  ## Returns

  The updated screen buffer with scroll region cleared.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_scroll_region(buffer, 5, 15)
      iex> buffer = ScreenBuffer.clear_scroll_region(buffer)
      iex> ScreenBuffer.get_scroll_region_boundaries(buffer)
      {0, 23}
  """
  @spec clear_scroll_region(t()) :: t()
  defdelegate clear_scroll_region(buffer), to: ScrollRegion, as: :clear

  @doc """
  Gets the current scroll region boundaries.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {start_line, end_line} representing the scroll region boundaries.
  If no scroll region is set, returns {0, height-1}.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.get_scroll_region_boundaries(buffer)
      {0, 23}

      iex> buffer = ScreenBuffer.set_scroll_region(buffer, 5, 15)
      iex> ScreenBuffer.get_scroll_region_boundaries(buffer)
      {5, 15}
  """
  @spec get_scroll_region_boundaries(t()) :: {non_neg_integer(), non_neg_integer()}
  defdelegate get_scroll_region_boundaries(buffer), to: ScrollRegion, as: :get_boundaries

  # --- Scrollback --- (Delegated to Scrollback)
  @doc """
  Gets the current scroll position (number of lines in scrollback).

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The number of lines in the scrollback buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.get_scroll_position(buffer)
      0
  """
  @spec get_scroll_position(t()) :: non_neg_integer()
  defdelegate get_scroll_position(buffer), to: Scrollback, as: :size

  # --- Selection --- (Delegated to Selection)
  @doc """
  Starts a text selection at the specified position.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The x-coordinate to start selection
  * `y` - The y-coordinate to start selection

  ## Returns

  The updated screen buffer with selection started.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.start_selection(buffer, 0, 0)
      iex> ScreenBuffer.get_selection_boundaries(buffer)
      {0, 0, 0, 0}

  ## Related Functions

  * `update_selection/3` - To modify the selection
  * `get_selection/1` - To get selected text
  * `in_selection?/3` - To check if a position is selected
  * `get_selection_boundaries/1` - To get selection coordinates
  * `get_text_in_region/5` - To get text from a region
  """
  @spec start_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate start_selection(buffer, x, y), to: Selection, as: :start

  @doc """
  Updates the current text selection to the specified position.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `x` - The x-coordinate to update selection to
  * `y` - The y-coordinate to update selection to

  ## Returns

  The updated screen buffer with selection updated.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.start_selection(buffer, 0, 0)
      iex> buffer = ScreenBuffer.update_selection(buffer, 4, 0)
      iex> ScreenBuffer.get_selection(buffer)
      "Hello"

  ## Related Functions

  * `start_selection/3` - To begin a selection
  * `get_selection/1` - To get selected text
  * `in_selection?/3` - To check if a position is selected
  * `get_selection_boundaries/1` - To get selection coordinates
  * `get_text_in_region/5` - To get text from a region
  """
  @spec update_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate update_selection(buffer, x, y), to: Selection, as: :update

  @doc """
  Gets the currently selected text.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The selected text as a string, or an empty string if no selection.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.start_selection(buffer, 0, 0)
      iex> buffer = ScreenBuffer.update_selection(buffer, 4, 0)
      iex> ScreenBuffer.get_selection(buffer)
      "Hello"
  """
  @spec get_selection(t()) :: String.t()
  defdelegate get_selection(buffer), to: Selection, as: :get_text

  @doc """
  Checks if a position is within the current selection.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `x` - The x-coordinate to check
  * `y` - The y-coordinate to check

  ## Returns

  `true` if the position is within the selection, `false` otherwise.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.start_selection(buffer, 0, 0)
      iex> buffer = ScreenBuffer.update_selection(buffer, 4, 0)
      iex> ScreenBuffer.in_selection?(buffer, 2, 0)
      true
  """
  @spec in_selection?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  defdelegate in_selection?(buffer, x, y), to: Selection, as: :contains?

  @doc """
  Gets the current selection boundaries.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {start_x, start_y, end_x, end_y} representing the selection boundaries,
  or `nil` if no selection.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.start_selection(buffer, 0, 0)
      iex> buffer = ScreenBuffer.update_selection(buffer, 4, 0)
      iex> ScreenBuffer.get_selection_boundaries(buffer)
      {0, 0, 4, 0}
  """
  @spec get_selection_boundaries(t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | nil
  defdelegate get_selection_boundaries(buffer), to: Selection, as: :get_boundaries

  @doc """
  Gets text in a specified region.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `start_x` - The starting x-coordinate
  * `start_y` - The starting y-coordinate
  * `end_x` - The ending x-coordinate
  * `end_y` - The ending y-coordinate

  ## Returns

  The text in the specified region as a string.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> ScreenBuffer.get_text_in_region(buffer, 0, 0, 4, 0)
      "Hello"
  """
  @spec get_text_in_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  defdelegate get_text_in_region(buffer, start_x, start_y, end_x, end_y), to: Selection

  # --- State Queries --- (Delegated to Queries)
  @doc """
  Checks if the buffer contains only default cells.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  `true` if the buffer is empty (contains only default cells), `false` otherwise.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.is_empty?(buffer)
      true

      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> ScreenBuffer.is_empty?(buffer)
      false
  """
  @spec is_empty?(t()) :: boolean()
  defdelegate is_empty?(buffer), to: Queries

  @doc """
  Gets the character at the specified position.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `x` - The x-coordinate
  * `y` - The y-coordinate

  ## Returns

  The character at the specified position, or `nil` if out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      "H"
  """
  @spec get_char(t(), non_neg_integer(), non_neg_integer()) :: String.t() | nil
  defdelegate get_char(buffer, x, y), to: Queries

  @doc """
  Gets the cell at the specified position.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `x` - The x-coordinate
  * `y` - The y-coordinate

  ## Returns

  The cell at the specified position, or `nil` if out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> cell = ScreenBuffer.get_cell(buffer, 0, 0)
      iex> cell.char
      "H"
  """
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  defdelegate get_cell(buffer, x, y), to: Queries

  @doc """
  Gets the line at the specified index.

  ## Parameters

  * `buffer` - The screen buffer to query
  * `line_index` - The line index

  ## Returns

  The line as a list of cells, or `nil` if out of bounds.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> line = ScreenBuffer.get_line(buffer, 0)
      iex> length(line)
      80
  """
  @spec get_line(t(), non_neg_integer()) :: list(Cell.t()) | nil
  defdelegate get_line(buffer, line_index), to: Queries

  @doc """
  Gets the current dimensions of the buffer.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {width, height} representing the buffer dimensions.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.get_dimensions(buffer)
      {80, 24}
  """
  @spec get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  defdelegate get_dimensions(buffer), to: Queries

  @doc """
  Gets the width of the buffer.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The width of the buffer in characters.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.get_width(buffer)
      80
  """
  @spec get_width(t()) :: non_neg_integer()
  defdelegate get_width(buffer), to: Queries

  @doc """
  Gets the height of the buffer.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  The height of the buffer in lines.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScreenBuffer.get_height(buffer)
      24
  """
  @spec get_height(t()) :: non_neg_integer()
  defdelegate get_height(buffer), to: Queries

  # --- Resizing --- (Delegated to Operations)
  @doc """
  Resizes the buffer to new dimensions.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `new_width` - The new width
  * `new_height` - The new height

  ## Returns

  The resized screen buffer.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.resize(buffer, 100, 30)
      iex> ScreenBuffer.get_dimensions(buffer)
      {100, 30}
  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate resize(buffer, new_width, new_height), to: Operations

  # --- Clearing/Erasing --- (Delegated to Eraser)
  @doc """
  Clears a region of the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `start_x` - The starting x-coordinate
  * `start_y` - The starting y-coordinate
  * `end_x` - The ending x-coordinate
  * `end_y` - The ending y-coordinate
  * `default_style` - The default text style to use

  ## Returns

  The updated screen buffer with the region cleared.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.clear_region(buffer, 0, 0, 4, 0, %{})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      " "

  ## Related Functions

  * `clear/2` - To clear the entire screen
  * `erase_in_display/4` - For ANSI-style display erasing
  * `erase_in_line/4` - For ANSI-style line erasing
  * `delete_characters/5` - To remove characters
  * `delete_lines/5` - To remove lines
  """
  @spec clear_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate clear_region(buffer, start_x, start_y, end_x, end_y, default_style), to: Eraser

  @doc """
  Erases content in the display based on the specified type.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `cursor_pos` - The current cursor position {x, y}
  * `type` - The type of erase operation
  * `default_style` - The default text style to use

  ## Returns

  The updated screen buffer with content erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.erase_in_display(buffer, {0, 0}, :from_cursor_to_end, %{})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      " "
  """
  @spec erase_in_display(
          t(),
          {non_neg_integer(), non_neg_integer()},
          atom(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate erase_in_display(buffer, cursor_pos, type, default_style), to: Eraser

  @doc """
  Erases content in the current line based on the specified type.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `cursor_pos` - The current cursor position {x, y}
  * `type` - The type of erase operation
  * `default_style` - The default text style to use

  ## Returns

  The updated screen buffer with line content erased.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.erase_in_line(buffer, {0, 0}, :from_cursor_to_end, %{})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      " "
  """
  @spec erase_in_line(
          t(),
          {non_neg_integer(), non_neg_integer()},
          atom(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate erase_in_line(buffer, cursor_pos, type, default_style), to: Eraser

  @doc """
  Clears the entire screen.
  """
  def clear_screen(%__MODULE__{} = buffer) do
    width = buffer.width
    height = buffer.height
    default_style = buffer.default_style
    # Create a row of default cells
    default_cell = Raxol.Terminal.Cell.new(" ", default_style)
    row = List.duplicate(default_cell, width)
    cells = List.duplicate(row, height)
    %__MODULE__{
      buffer |
      cells: cells,
      scrollback: [],
      selection: nil,
      cursor_position: {0, 0},
      damage_regions: [{0, 0, width - 1, height - 1}],
      scroll_region: {0, height - 1}
    }
  end

  # --- Line Operations --- (Delegated to LineOperations)
  @doc """
  Deletes lines from the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `start_y` - The starting line to delete from
  * `count` - Number of lines to delete
  * `default_style` - The default text style to use
  * `scroll_region` - Optional scroll region boundaries

  ## Returns

  The updated screen buffer with lines deleted.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.delete_lines(buffer, 0, 1, %{})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      " "

  ## Related Functions

  * `insert_lines/4` - To add new lines
  * `prepend_lines/2` - To add lines at the top
  * `pop_top_lines/2` - To remove lines from the top
  * `scroll_up/3` and `scroll_down/3` - For scrolling operations
  * `set_scroll_region/3` - To define scroll boundaries
  """
  @spec delete_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  defdelegate delete_lines(buffer, start_y, count, default_style, scroll_region \\ nil),
    to: LineOperations

  @doc """
  Prepends lines to the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `lines` - List of lines to prepend

  ## Returns

  The updated screen buffer with lines prepended.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> lines = [List.duplicate(%Cell{char: "A"}, 80)]
      iex> buffer = ScreenBuffer.prepend_lines(buffer, lines)
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      "A"
  """
  @spec prepend_lines(t(), list(list(Cell.t()))) :: t()
  defdelegate prepend_lines(buffer, lines), to: LineOperations

  @doc """
  Pops lines from the top of the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `count` - Number of lines to pop

  ## Returns

  A tuple {popped_lines, updated_buffer}.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> {popped, buffer} = ScreenBuffer.pop_top_lines(buffer, 1)
      iex> length(popped)
      1
  """
  @spec pop_top_lines(t(), non_neg_integer()) :: {list(list(Cell.t())), t()}
  defdelegate pop_top_lines(buffer, count), to: LineOperations

  # --- Character Operations --- (Delegated to CharEditor)
  @doc """
  Deletes characters from the buffer.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `row` - The row to delete from
  * `col` - The starting column
  * `count` - Number of characters to delete
  * `default_style` - The default text style to use

  ## Returns

  The updated screen buffer with characters deleted.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      iex> buffer = ScreenBuffer.delete_characters(buffer, 0, 0, 2, %{})
      iex> ScreenBuffer.get_char(buffer, 0, 0)
      "l"
  """
  @spec delete_characters(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate delete_characters(buffer, row, col, count, default_style), to: CharEditor

  # --- Content Operations --- (Delegated to Content)
  @doc """
  Gets the content of the buffer.
  """
  @spec get_content(t()) :: String.t()
  defdelegate get_content(buffer), to: Content

  @doc """
  Gets a cell at the specified position.
  """
  @spec get_cell_at(t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  defdelegate get_cell_at(buffer, x, y), to: Content, as: :get_cell

  @doc """
  Gets a character at the specified position.
  """
  @spec get_char(t(), non_neg_integer(), non_neg_integer()) :: String.t()
  defdelegate get_char(buffer, x, y), to: Content

  # --- Line Operations --- (Delegated to LineOperations)
  @doc """
  Inserts lines at the specified position.
  """
  @spec insert_lines(t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: t()
  defdelegate insert_lines(buffer, y, count, style), to: LineOperations

  @doc """
  Deletes lines at the specified position.
  """
  @spec delete_lines(t(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: t()
  defdelegate delete_lines(buffer, y, count, style), to: LineOperations

  # --- Character Operations --- (Delegated to CharEditor)
  @doc """
  Inserts characters at the specified position.
  """
  @spec insert_characters(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: t()
  defdelegate insert_characters(buffer, x, y, count, style), to: CharEditor

  @doc """
  Deletes characters at the specified position.
  """
  @spec delete_characters(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), TextFormatting.text_style()) :: t()
  defdelegate delete_characters(buffer, x, y, count, style), to: CharEditor

  # --- Scrolling Operations --- (Delegated to ScrollRegion)
  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  @spec scroll_up(t(), non_neg_integer()) :: t()
  defdelegate scroll_up(buffer, lines), to: ScrollRegion

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  @spec scroll_down(t(), non_neg_integer()) :: t()
  defdelegate scroll_down(buffer, lines), to: ScrollRegion

  # --- Dimension Operations --- (Delegated to Queries)
  @doc """
  Gets the width of the buffer.
  """
  @spec get_width(t()) :: non_neg_integer()
  defdelegate get_width(buffer), to: Queries

  @doc """
  Gets the height of the buffer.
  """
  @spec get_height(t()) :: non_neg_integer()
  defdelegate get_height(buffer), to: Queries

  @doc """
  Gets the dimensions of the buffer.
  """
  @spec get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  defdelegate get_dimensions(buffer), to: Queries

  # --- Line Operations --- (Delegated to LineEditor)
  @doc """
  Gets a line from the buffer.
  """
  @spec get_line(t(), non_neg_integer()) :: list(Cell.t()) | nil
  defdelegate get_line(buffer, line_index), to: LineEditor

  @doc """
  Puts a line in the buffer.
  """
  @spec put_line(t(), non_neg_integer(), list(Cell.t())) :: t()
  defdelegate put_line(buffer, line_index, new_cells), to: LineEditor

  # --- Cleanup ---
  @doc """
  Cleans up the buffer resources.
  """
  @spec cleanup(t()) :: :ok
  def cleanup(_buffer) do
    :ok
  end

  # --- Memory Management ---
  @impl true
  defdelegate get_memory_usage(buffer), to: MemoryManager
  @impl true
  defdelegate cleanup(buffer), to: MemoryManager

  # --- Cursor Operations ---
  @impl true
  defdelegate set_cursor_position(buffer, x, y), to: CursorManager
  @impl true
  defdelegate get_cursor_position(buffer), to: CursorManager
  @impl true
  defdelegate set_cursor_visibility(buffer, visible), to: CursorManager
  @impl true
  defdelegate set_cursor_style(buffer, style), to: CursorManager
  @impl true
  defdelegate set_cursor_blink(buffer, blink), to: CursorManager

  # --- Charset Operations ---
  @impl true
  defdelegate set_charset(buffer, charset, slot), to: ScreenBuffer
  @impl true
  defdelegate get_state(buffer), to: CharsetManager
  @impl true
  defdelegate update_state(buffer, state), to: CharsetManager
  @impl true
  defdelegate designate_charset(buffer, slot, charset), to: CharsetManager
  @impl true
  defdelegate invoke_g_set(buffer, slot), to: CharsetManager
  @impl true
  defdelegate get_current_g_set(buffer), to: CharsetManager
  @impl true
  defdelegate get_designated_charset(buffer, slot), to: CharsetManager
  @impl true
  defdelegate reset_state(buffer), to: CharsetManager
  @impl true
  defdelegate apply_single_shift(buffer, slot), to: CharsetManager
  @impl true
  defdelegate get_single_shift(buffer), to: CharsetManager

  # --- Formatting Operations ---
  @impl true
  defdelegate get_style(buffer), to: FormattingManager
  @impl true
  defdelegate update_style(buffer, style), to: FormattingManager
  @impl true
  defdelegate set_attribute(buffer, attribute), to: FormattingManager
  @impl true
  defdelegate reset_attribute(buffer, attribute), to: FormattingManager
  @impl true
  defdelegate set_foreground(buffer, color), to: FormattingManager
  @impl true
  defdelegate set_background(buffer, color), to: FormattingManager
  @impl true
  defdelegate reset_all_attributes(buffer), to: FormattingManager
  @impl true
  defdelegate get_foreground(buffer), to: FormattingManager
  @impl true
  defdelegate get_background(buffer), to: FormattingManager
  @impl true
  defdelegate attribute_set?(buffer, attribute), to: FormattingManager
  @impl true
  defdelegate get_set_attributes(buffer), to: FormattingManager

  # --- Terminal State Operations ---
  @impl true
  defdelegate get_state_stack(buffer), to: TerminalStateManager
  @impl true
  defdelegate update_state_stack(buffer, stack), to: TerminalStateManager
  @impl true
  defdelegate save_state(buffer), to: TerminalStateManager
  @impl true
  defdelegate restore_state(buffer), to: TerminalStateManager
  @impl true
  defdelegate has_saved_states?(buffer), to: TerminalStateManager
  @impl true
  defdelegate get_saved_states_count(buffer), to: TerminalStateManager
  @impl true
  defdelegate clear_saved_states(buffer), to: TerminalStateManager
  @impl true
  defdelegate get_current_state(buffer), to: TerminalStateManager
  @impl true
  defdelegate update_current_state(buffer, state), to: TerminalStateManager

  # --- Output Manager Operations ---
  @impl true
  defdelegate write(buffer, data), to: Output.Manager
  @impl true
  defdelegate flush_output(buffer), to: Output.Manager
  @impl true
  defdelegate clear_output_buffer(buffer), to: Output.Manager
  @impl true
  defdelegate get_output_buffer(buffer), to: Output.Manager
  @impl true
  defdelegate enqueue_control_sequence(buffer, sequence), to: Output.Manager

  # --- Cell Operations ---
  @impl true
  defdelegate is_empty?(cell), to: Cell

  # --- Metrics Operations ---
  @impl true
  defdelegate get_metric_value(buffer, metric), to: MetricsHelper
  @impl true
  defdelegate verify_metrics(buffer, metrics), to: MetricsHelper
  @impl true
  defdelegate collect_metrics(buffer, metrics), to: MetricsHelper

  # --- File Watcher Operations ---
  @impl true
  defdelegate handle_file_event(buffer, event), to: FileWatcher
  @impl true
  defdelegate handle_debounced_events(buffer, events, timeout), to: FileWatcher
  @impl true
  defdelegate cleanup_file_watching(buffer), to: FileWatcher

  # --- Scroll Operations ---
  @impl true
  defdelegate get_size(buffer), to: Scroll

  # --- Metrics Operations ---
  @impl true
  defdelegate record_performance(buffer, metric, value), to: UnifiedCollector
  @impl true
  defdelegate record_operation(buffer, operation, value), to: UnifiedCollector
  @impl true
  defdelegate record_resource(buffer, resource, value), to: UnifiedCollector
  @impl true
  defdelegate get_metrics_by_type(buffer, type), to: UnifiedCollector
  @impl true
  defdelegate record_metric(buffer, metric, value, tags), to: UnifiedCollector
  @impl true
  defdelegate get_metric(buffer, metric, tags), to: UnifiedCollector

  # --- Cache Operations ---
  @impl true
  defdelegate system_time(buffer), to: Cache.System

  # --- Mode Handler Operations ---
  @impl true
  defdelegate handle_mode(buffer, mode, value), to: DECPrivateHandler
  @impl true
  defdelegate handle_mode(buffer, mode, value), to: StandardHandler

  # --- Metrics Operations ---
  @impl true
  defdelegate start_link(buffer), to: UnifiedCollector
  @impl true
  defdelegate stop(buffer), to: UnifiedCollector
  @impl true
  defdelegate stop(buffer), to: Aggregator
  @impl true
  defdelegate stop(buffer), to: Visualizer
  @impl true
  defdelegate stop(buffer), to: AlertManager

  # --- Visualizer Operations ---
  @impl true
  defdelegate create_chart(buffer, data, options), to: Visualizer

  # --- Cell Operations ---
  @impl true
  defdelegate new(char, style), to: Cell
  @impl true
  defdelegate new(), to: TextFormatting

  # --- Screen Operations ---
  @impl true
  defdelegate scroll_up(buffer, lines), to: Screen
  @impl true
  defdelegate scroll_down(buffer, lines), to: Screen
  @impl true
  defdelegate clear_screen(buffer), to: Screen
  @impl true
  defdelegate clear_line(buffer, line), to: Screen

  # --- Screen Buffer Operations ---
  @impl true
  defdelegate mark_damaged(buffer, x, y, width, height), to: ScreenBuffer
  @impl true
  defdelegate erase_from_cursor_to_end(buffer), to: ScreenBuffer
  @impl true
  defdelegate erase_from_start_to_cursor(buffer), to: ScreenBuffer
  @impl true
  defdelegate erase_all(buffer), to: ScreenBuffer
  @impl true
  defdelegate erase_all_with_scrollback(buffer), to: ScreenBuffer
  @impl true
  defdelegate erase_from_cursor_to_end_of_line(buffer), to: ScreenBuffer
  @impl true
  defdelegate erase_from_start_of_line_to_cursor(buffer), to: ScreenBuffer
  @impl true
  defdelegate erase_line(buffer), to: ScreenBuffer
  @impl true
  defdelegate set_attributes(buffer, attributes), to: ScreenBuffer
  @impl true
  defdelegate set_charset(buffer, charset, slot), to: ScreenBuffer
  @impl true
  defdelegate write_char(buffer, x, y, char), to: ScreenBuffer

  # --- User Preferences Operations ---
  @impl true
  defdelegate get_preferences(), to: UserPreferences
  @impl true
  defdelegate set_preferences(preferences), to: UserPreferences

  # --- System Operations ---
  @impl true
  defdelegate get_update_settings(), to: System.Updater

  # --- Cloud Operations ---
  @impl true
  defdelegate get_config(), to: Cloud.Config
  @impl true
  defdelegate set_config(config), to: Cloud.Config

  # --- Theme Operations ---
  @impl true
  defdelegate current_theme(), to: Theme
  @impl true
  defdelegate light_theme(), to: Theme

  # --- CSI Handler Operations ---
  @impl true
  defdelegate handle_csi_sequence(buffer, sequence, params), to: CSIHandlers

  # --- List Operations ---
  @impl true
  defdelegate replace_slice(list, start, len, replacement), to: List

end
