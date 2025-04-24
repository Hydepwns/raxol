defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Manages the terminal's screen buffer, including operations for resizing, scrolling, and selection handling.
  """

  require Logger

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.CharacterHandling
  alias Raxol.Terminal.ANSI.TextFormatting

  defstruct [
    :cells,
    :scrollback,
    :scrollback_limit,
    :selection,
    :scroll_region,
    :width,
    :height
  ]

  @type t :: %__MODULE__{
          cells: list(list(Cell.t())),
          scrollback: list(list(Cell.t())),
          scrollback_limit: non_neg_integer(),
          selection: {integer(), integer(), integer(), integer()} | nil,
          scroll_region: {integer(), integer()} | nil,
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  @doc """
  Creates a new screen buffer with the specified dimensions.
  """
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height, scrollback_limit \\ 1000) do
    # Validate width and height are valid numbers
    actual_width = if is_number(width) and width > 0, do: width, else: 80
    actual_height = if is_number(height) and height > 0, do: height, else: 24

    # Log warning if invalid dimensions provided
    if !(is_number(width) and is_number(height)) do
      Logger.warning(
        "Invalid dimensions provided to ScreenBuffer.new: width=#{inspect(width)}, height=#{inspect(height)}. Using defaults."
      )
    end

    # Validate scrollback_limit
    {valid_scrollback_limit, scrollback_warning} =
      cond do
        is_integer(scrollback_limit) and scrollback_limit >= 0 ->
          {scrollback_limit, nil}

        true ->
          warning =
            "Invalid scrollback_limit provided to ScreenBuffer.new: #{inspect(scrollback_limit)}. Using default 1000."

          # Default to 1000 if invalid
          {1000, warning}
      end

    # Log warning if scrollback_limit was invalid
    if scrollback_warning, do: Logger.warning(scrollback_warning)

    %__MODULE__{
      cells:
        List.duplicate(List.duplicate(Cell.new(), actual_width), actual_height),
      scrollback: [],
      scrollback_limit: valid_scrollback_limit,
      selection: nil,
      scroll_region: nil,
      width: actual_width,
      height: actual_height
    }
  end

  @doc """
  Writes a character to the buffer at the specified position.
  Handles wide characters by taking up two cells when necessary.
  Accepts an optional style to apply to the cell.
  """
  # Suppress spurious exact_eq warning (0 == 2)
  @dialyzer {:nowarn_function, write_char: 5}
  @spec write_char(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: t()
  def write_char(%__MODULE__{} = buffer, x, y, char, style \\ nil)
      when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      width = CharacterHandling.get_char_width(char)
      # Placeholder
      cell_style = style || %{}

      cells =
        List.update_at(buffer.cells, y, fn row ->
          new_cell = Cell.new(char, cell_style)

          if width == 2 and x + 1 < buffer.width do
            # For wide characters, mark the next cell as a placeholder
            # inheriting the style from the primary cell.
            row
            |> List.update_at(x, fn _ -> new_cell end)
            |> List.update_at(x + 1, fn _ ->
              Cell.new_wide_placeholder(cell_style)
            end)
          else
            List.update_at(row, x, fn _ -> new_cell end)
          end
        end)

      %{buffer | cells: cells}
    else
      buffer
    end
  end

  @doc """
  Writes a string to the buffer at the specified position.
  Handles wide characters and bidirectional text.
  """
  @spec write_string(t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          t()
  def write_string(%__MODULE__{} = buffer, x, y, string)
      when x >= 0 and y >= 0 do
    segments = CharacterHandling.process_bidi_text(string)

    Enum.reduce(segments, {buffer, x}, fn {_type, segment},
                                          {acc_buffer, acc_x} ->
      {new_buffer, new_x} = write_segment(acc_buffer, acc_x, y, segment)
      {new_buffer, new_x}
    end)
    |> elem(0)
  end

  # Silence potential spurious no_return warning
  @dialyzer {:nowarn_function, write_segment: 4}
  @spec write_segment(t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          {t(), non_neg_integer()}
  defp write_segment(buffer, x, y, segment) do
    Enum.reduce(String.graphemes(segment), {buffer, x}, fn char,
                                                           {acc_buffer, acc_x} ->
      width = CharacterHandling.get_char_width(char)

      if acc_x + width <= acc_buffer.width do
        {write_char(acc_buffer, acc_x, y, char), acc_x + width}
      else
        {acc_buffer, acc_x}
      end
    end)
  end

  @doc """
  Scrolls the buffer up by the specified number of lines, optionally within a specified scroll region.
  """
  @spec scroll_up(
          t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  def scroll_up(%__MODULE__{} = buffer, lines, scroll_region \\ nil)
      when lines > 0 do
    # Use the provided scroll region or the one stored in the buffer
    effective_scroll_region = scroll_region || buffer.scroll_region

    # Store the effective scroll region temporarily to use with get_scroll_region_boundaries
    buffer_with_region = %{buffer | scroll_region: effective_scroll_region}

    {scroll_start, scroll_end} =
      get_scroll_region_boundaries(buffer_with_region)

    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than the visible region, clear it
      clear_scroll_region(buffer, scroll_start, scroll_end, visible_lines)
    else
      # Get the lines within the scroll region
      scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
      # Split into scrolled and remaining lines
      {scrolled_lines, remaining_lines} = Enum.split(scroll_region_lines, lines)

      # Add scrolled lines to scrollback buffer
      new_scrollback =
        (scrolled_lines ++ buffer.scrollback)
        |> Enum.take(buffer.scrollback_limit)

      # Create new empty lines for the bottom
      empty_lines =
        List.duplicate(List.duplicate(Cell.new(), buffer.width), lines)

      # Construct the new cells array by replacing the scroll region
      new_region_content = remaining_lines ++ empty_lines

      replace_scroll_region(
        buffer,
        scroll_start,
        scroll_end,
        new_region_content,
        new_scrollback
      )
    end
  end

  @doc """
  Scrolls the buffer down by the specified number of lines, optionally within a specified scroll region.
  """
  @spec scroll_down(
          t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  def scroll_down(%__MODULE__{} = buffer, lines, scroll_region \\ nil)
      when lines > 0 do
    # Use the provided scroll region or the one stored in the buffer
    effective_scroll_region = scroll_region || buffer.scroll_region

    # Store the effective scroll region temporarily to use with get_scroll_region_boundaries
    buffer_with_region = %{buffer | scroll_region: effective_scroll_region}

    {scroll_start, scroll_end} =
      get_scroll_region_boundaries(buffer_with_region)

    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than the visible region, clear it
      clear_scroll_region(buffer, scroll_start, scroll_end, visible_lines)
    else
      if length(buffer.scrollback) >= lines do
        # Get lines from scrollback
        {scroll_lines, new_scrollback} = Enum.split(buffer.scrollback, lines)

        # Get the lines within the scroll region
        scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
        # Drop lines from the bottom
        shifted_lines = Enum.drop(scroll_region_lines, -lines)

        # Construct the new cells array by replacing the scroll region
        new_region_content = scroll_lines ++ shifted_lines

        replace_scroll_region(
          buffer,
          scroll_start,
          scroll_end,
          new_region_content,
          new_scrollback
        )
      else
        buffer
      end
    end
  end

  # Helper functions for scrolling
  defp clear_scroll_region(buffer, scroll_start, scroll_end, visible_lines) do
    # Create empty region
    empty_region =
      List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)

    # Replace the scroll region with empty cells
    replace_scroll_region(
      buffer,
      scroll_start,
      scroll_end,
      empty_region,
      buffer.scrollback
    )
  end

  defp replace_scroll_region(
         buffer,
         scroll_start,
         scroll_end,
         new_content,
         new_scrollback
       ) do
    # Construct the new cells array by replacing the scroll region
    new_cells =
      Enum.slice(buffer.cells, 0, scroll_start) ++
        new_content ++
        Enum.slice(
          buffer.cells,
          scroll_end + 1,
          buffer.height - (scroll_end + 1)
        )

    # Return updated buffer
    %{buffer | cells: new_cells, scrollback: new_scrollback}
  end

  @doc """
  Sets a scroll region in the buffer.
  """
  @spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_scroll_region(%__MODULE__{} = buffer, start_line, end_line)
      when start_line >= 0 and end_line >= start_line do
    %{buffer | scroll_region: {start_line, end_line}}
  end

  @doc """
  Clears the scroll region.
  """
  @spec clear_scroll_region(t()) :: t()
  def clear_scroll_region(%__MODULE__{} = buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Gets the current scroll position.
  """
  @spec get_scroll_position(t()) :: non_neg_integer()
  def get_scroll_position(%__MODULE__{} = buffer) do
    length(buffer.scrollback)
  end

  @doc """
  Gets the boundaries of the current scroll region.
  """
  @spec get_scroll_region_boundaries(t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_scroll_region_boundaries(%__MODULE__{} = buffer) do
    case buffer.scroll_region do
      {start, ending} -> {start, ending}
      nil -> {0, buffer.height - 1}
    end
  end

  @doc """
  Starts a selection at the specified coordinates.
  """
  @spec start_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  def start_selection(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | selection: {x, y, x, y}}
  end

  @doc """
  Updates the endpoint of the current selection.
  """
  @spec update_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  def update_selection(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    case buffer.selection do
      {start_x, start_y, _end_x, _end_y} ->
        %{buffer | selection: {start_x, start_y, x, y}}

      nil ->
        buffer
    end
  end

  @doc """
  Gets the text within the current selection.
  """
  @spec get_selection(t()) :: String.t()
  def get_selection(%__MODULE__{} = buffer) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        get_text_in_region(buffer, start_x, start_y, end_x, end_y)

      nil ->
        ""
    end
  end

  @doc """
  Checks if a position is within the current selection.
  """
  @spec in_selection?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def in_selection?(%__MODULE__{} = buffer, x, y) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        min_x = min(start_x, end_x)
        max_x = max(start_x, end_x)
        min_y = min(start_y, end_y)
        max_y = max(start_y, end_y)
        x >= min_x and x <= max_x and y >= min_y and y <= max_y

      nil ->
        false
    end
  end

  @doc """
  Gets the boundaries of the current selection.
  """
  @spec get_selection_boundaries(t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
          | nil
  def get_selection_boundaries(%__MODULE__{} = buffer) do
    buffer.selection
  end

  @doc """
  Gets the text within a specified region of the buffer.
  """
  @spec get_text_in_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  def get_text_in_region(%__MODULE__{} = buffer, start_x, start_y, end_x, end_y) do
    min_x = min(start_x, end_x)
    max_x = max(start_x, end_x)
    min_y = min(start_y, end_y)
    max_y = max(start_y, end_y)

    buffer.cells
    |> Enum.slice(min_y..max_y)
    |> Enum.map_join("\n", fn row ->
      row
      |> Enum.slice(min_x..max_x)
      |> Enum.map_join("", &Cell.get_char/1)
    end)
  end

  @doc """
  Resizes the screen buffer to the new dimensions.
  Preserves content that fits within the new bounds.
  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%__MODULE__{} = buffer, new_width, new_height)
      when is_integer(new_width) and new_width > 0 and is_integer(new_height) and
             new_height > 0 do
    old_width = buffer.width
    old_height = buffer.height

    # Create a new empty cell grid with the new dimensions
    new_cells =
      List.duplicate(List.duplicate(Cell.new(), new_width), new_height)

    # Determine the range of rows and columns to copy
    max_y_copy = min(old_height, new_height)
    max_x_copy = min(old_width, new_width)

    # Copy content from the old buffer to the new buffer
    copied_cells =
      Enum.reduce(0..(max_y_copy - 1), new_cells, fn y, acc_new_cells ->
        # Calculate the corresponding row index in the old buffer
        # If shrinking height, copy from the bottom up
        old_row_index =
          if new_height < old_height do
            # New logic: Keep top content
            y
          else
            y
          end

        # Ensure old_row_index is within bounds (should be, but belt and suspenders)
        if old_row_index >= 0 and old_row_index < old_height do
          old_row = Enum.at(buffer.cells, old_row_index)
          new_row = Enum.at(acc_new_cells, y)

          # Copy cells within the column range
          updated_new_row =
            Enum.reduce(0..(max_x_copy - 1), new_row, fn x, acc_new_row ->
              # Ensure old_row is not nil before accessing Enum.at/2
              if old_row do
                old_cell = Enum.at(old_row, x)
                List.replace_at(acc_new_row, x, old_cell)
              else
                # Should not happen if old_row_index logic is correct
                acc_new_row
              end
            end)

          List.replace_at(acc_new_cells, y, updated_new_row)
        else
          # Row index out of bounds, shouldn't happen with correct logic
          acc_new_cells
        end
      end)

    # Return a new buffer struct with updated dimensions and copied cells
    # Keep scrollback, limit, region, selection for now (might need adjustment)
    %{
      buffer
      | cells: copied_cells,
        width: new_width,
        height: new_height,
        # Reset scroll region and selection on resize?
        # Reset scroll region
        scroll_region: nil,
        # Clear selection
        selection: nil
    }
  end

  @doc """
  Gets the current width of the screen buffer.
  """
  @spec get_width(t()) :: non_neg_integer()
  def get_width(%__MODULE__{} = buffer) do
    buffer.width
  end

  @doc """
  Gets the current height of the screen buffer.
  """
  @spec get_height(t()) :: non_neg_integer()
  def get_height(%__MODULE__{} = buffer) do
    buffer.height
  end

  @doc """
  Gets the dimensions of the screen buffer.
  """
  @spec get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_dimensions(%__MODULE__{} = buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets a specific line from the buffer.
  """
  @spec get_line(t(), non_neg_integer()) :: list(Cell.t()) | nil
  def get_line(%__MODULE__{} = buffer, line_index) when line_index >= 0 do
    if line_index < buffer.height do
      Enum.at(buffer.cells, line_index)
    else
      nil
    end
  end

  @doc """
  Gets a specific cell from the buffer.
  """
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  def get_cell(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      buffer.cells |> Enum.at(y) |> Enum.at(x)
    else
      nil
    end
  end

  @doc """
  Clears a rectangular region of the buffer.
  """
  @spec clear_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  def clear_region(%__MODULE__{} = buffer, start_x, start_y, end_x, end_y) do
    Enum.reduce(start_y..end_y, buffer, fn y, acc_buffer ->
      if y >= 0 and y < acc_buffer.height do
        row = Enum.at(acc_buffer.cells, y)

        new_row =
          Enum.reduce(start_x..end_x, row, fn x, acc_row ->
            if x >= 0 and x < acc_buffer.width do
              List.replace_at(acc_row, x, Cell.new())
            else
              acc_row
            end
          end)

        %{
          acc_buffer
          | cells: List.update_at(acc_buffer.cells, y, fn _ -> new_row end)
        }
      else
        acc_buffer
      end
    end)
  end

  @doc """
  Deletes `n` lines starting from `start_y`.
  Lines below `start_y` are shifted up.
  `n` blank lines are added at the bottom of the affected region.
  Respects the scroll region if set.
  """
  @spec delete_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  def delete_lines(%__MODULE__{} = buffer, start_y, n, scroll_region)
      when n > 0 do
    # Determine the effective scroll region (top, bottom)
    {scroll_start, scroll_end} =
      case scroll_region do
        {top, bottom} -> {top, bottom}
        nil -> {0, buffer.height - 1}
      end

    # Ensure start_y is within the scroll region
    if start_y < scroll_start or start_y > scroll_end do
      # Cursor is outside the scroll region, do nothing
      buffer
    else
      # Number of lines in the scroll region
      visible_lines = scroll_end - scroll_start + 1

      # Ensure we don't delete more lines than available in the region below start_y
      lines_to_delete = min(n, scroll_end - start_y + 1)

      if lines_to_delete == 0 do
        # Nothing to delete
        buffer
      else
        # Get the lines within the scroll region
        scroll_region_cells = Enum.slice(buffer.cells, scroll_start..scroll_end)

        # Calculate indices relative to the scroll region
        relative_start_y = start_y - scroll_start

        # Split the region cells into parts: before deletion, deleted, after deletion
        {before_deleted, rest} =
          Enum.split(scroll_region_cells, relative_start_y)

        {_deleted_lines, after_deleted} = Enum.split(rest, lines_to_delete)

        # Create new blank lines to insert at the bottom
        blank_lines =
          List.duplicate(
            List.duplicate(Cell.new(), buffer.width),
            lines_to_delete
          )

        # Combine the parts to form the new region content
        new_region_content = before_deleted ++ after_deleted ++ blank_lines

        # Ensure the new region content has the correct number of lines
        new_region_content = Enum.take(new_region_content, visible_lines)

        # Construct the new full cells list
        new_cells =
          Enum.slice(buffer.cells, 0, scroll_start) ++
            new_region_content ++
            Enum.slice(
              buffer.cells,
              scroll_end + 1,
              buffer.height - (scroll_end + 1)
            )

        %{buffer | cells: new_cells}
      end
    end
  end

  @doc """
  Gets the cell at the specified coordinates.
  Returns nil if coordinates are out of bounds.
  """
  @spec get_cell_at(t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  def get_cell_at(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      buffer.cells |> Enum.at(y) |> Enum.at(x)
    else
      nil
    end
  end

  @doc """
  Calculates the difference between the current buffer state and a list of desired cell changes.
  Can handle both a list of lists (cells) or a list of tuples with cell maps.

  Returns a list of cell tuples representing only the cells that need to be updated.
  """
  @spec diff(
          t(),
          list(list(Cell.t()))
          | list({non_neg_integer(), non_neg_integer(), map()})
        ) ::
          list({integer(), integer(), Cell.t() | map()})
  def diff(%__MODULE__{} = buffer, changes) when is_list(changes) do
    cond do
      # Empty list case
      Enum.empty?(changes) ->
        []

      # Handle case where changes is a list of lists (old format)
      is_list(hd(changes)) ->
        get_changes(buffer, changes)

      # Handle case where changes is a list of {x, y, cell_map} tuples
      match?({_, _, _}, hd(changes)) ->
        Enum.filter(changes, fn {x, y, desired_cell_map} ->
          # Convert desired map to a Cell struct for proper comparison
          desired_cell_struct = Cell.from_map(desired_cell_map)
          current_cell_struct = get_cell_at(buffer, x, y)

          # Compare if the desired cell struct is valid and different from the current one
          # Use Cell.equals?/2 for comparison
          case {desired_cell_struct, current_cell_struct} do
            {nil, _} ->
              # Invalid desired cell map, skip
              false

            {_desired, nil} ->
              # Current cell is outside buffer (shouldn't happen if called correctly), or buffer uninitialized?
              # Treat as different if desired is valid.
              true

            {desired, current} ->
              # Compare the structs directly
              not Cell.equals?(current, desired)
          end
        end)

      # Default case for other formats
      true ->
        []
    end
  end

  @doc """
  Gets the changes between the current buffer and the provided new cells.
  Returns a list of tuple {x, y, cell} for each changed cell.
  """
  @spec get_changes(t(), list(list(Cell.t()))) ::
          list({integer(), integer(), Cell.t()})
  def get_changes(%__MODULE__{} = buffer, new_cells) do
    changes = []

    # Iterate through the cells and find differences
    Enum.with_index(new_cells)
    |> Enum.reduce(changes, fn {row, y}, acc ->
      Enum.with_index(row)
      |> Enum.reduce(acc, fn {cell, x}, inner_acc ->
        # Get the current cell at this position
        current_cell = get_cell(buffer, x, y)

        # If cells are different, add to changes
        if !Cell.equals?(current_cell, cell) do
          [{x, y, cell} | inner_acc]
        else
          inner_acc
        end
      end)
    end)
  end

  @doc """
  Updates the buffer state by applying a list of cell changes.
  Can handle both cell structs and cell maps formats.

  Returns a new buffer `t()` with the changes applied.
  """
  @spec update(
          t(),
          list({non_neg_integer(), non_neg_integer(), Cell.t() | map()})
        ) :: t()
  def update(%__MODULE__{} = buffer, changes) when is_list(changes) do
    Enum.reduce(changes, buffer, fn
      # When the third element is a Cell struct
      {x, y, %Cell{} = cell}, acc_buffer when is_integer(x) and is_integer(y) ->
        if y >= 0 and y < acc_buffer.height and x >= 0 and x < acc_buffer.width do
          cells =
            List.update_at(acc_buffer.cells, y, fn row ->
              List.update_at(row, x, fn _ -> cell end)
            end)

          %{acc_buffer | cells: cells}
        else
          acc_buffer
        end

      # When the third element is a map that needs conversion to Cell struct
      {x, y, cell_map}, acc_buffer
      when is_integer(x) and is_integer(y) and is_map(cell_map) ->
        if y >= 0 and y < acc_buffer.height and x >= 0 and x < acc_buffer.width do
          # Convert the cell map from Runtime into a Cell struct
          new_cell_struct = Cell.from_map(cell_map)

          # Check if conversion was successful and cell is not nil
          if new_cell_struct do
            is_wide =
              CharacterHandling.get_char_width(new_cell_struct.char) == 2 and
                !new_cell_struct.is_wide_placeholder

            new_rows =
              List.update_at(acc_buffer.cells, y, fn row ->
                row_with_primary = List.replace_at(row, x, new_cell_struct)
                # Handle wide character placeholder if needed and space allows
                if is_wide and x + 1 < acc_buffer.width do
                  List.replace_at(
                    row_with_primary,
                    x + 1,
                    Cell.new_wide_placeholder(new_cell_struct.style)
                  )
                else
                  row_with_primary
                end
              end)

            %{acc_buffer | cells: new_rows}
          else
            # Failed to convert cell map, ignore this change
            Logger.warning(
              "[ScreenBuffer.update] Failed to convert cell map, skipping change: #{inspect(cell_map)} at (#{x}, #{y})"
            )

            acc_buffer
          end
        else
          # Ignore changes outside buffer bounds
          acc_buffer
        end

      # Default case for unexpected format
      _, acc_buffer ->
        acc_buffer
    end)
  end

  # For backward compatibility
  @doc false
  @deprecated "Use in_selection?/3 instead"
  def is_in_selection?(buffer, x, y), do: in_selection?(buffer, x, y)

  @doc """
  Erases parts of the display based on the cursor position.
  Type can be :to_end, :to_beginning, or :all.
  Requires the cursor state for positioning.
  """
  @spec erase_in_display(t(), Raxol.Terminal.Cursor.Manager.t(), atom()) :: t()
  def erase_in_display(%__MODULE__{} = buffer, cursor, type) do
    # Access position directly from cursor struct
    {cursor_x, cursor_y} = cursor.position
    blank_cell = Cell.new()

    case type do
      :to_end ->
        # Erase from cursor to end of the line
        buffer_after_line_erase =
          erase_line_part(
            buffer,
            cursor_y,
            cursor_x,
            buffer.width - 1,
            blank_cell
          )

        # Erase lines below the cursor
        Enum.reduce(
          (cursor_y + 1)..(buffer.height - 1),
          buffer_after_line_erase,
          fn y, acc_buffer ->
            erase_line_part(acc_buffer, y, 0, buffer.width - 1, blank_cell)
          end
        )

      :to_beginning ->
        # Erase from beginning of line to cursor
        buffer_after_line_erase =
          erase_line_part(buffer, cursor_y, 0, cursor_x, blank_cell)

        # Erase lines above the cursor
        Enum.reduce(0..(cursor_y - 1), buffer_after_line_erase, fn y,
                                                                   acc_buffer ->
          erase_line_part(acc_buffer, y, 0, buffer.width - 1, blank_cell)
        end)

      :all ->
        # Erase the entire screen
        %{
          buffer
          | cells:
              List.duplicate(
                List.duplicate(blank_cell, buffer.width),
                buffer.height
              )
        }

      # ED 3: Erase All + Scrollback (Optional)
      # :all_with_scrollback ->
      #   %{
      #     buffer
      #     | cells: List.duplicate(List.duplicate(blank_cell, buffer.width), buffer.height),
      #       scrollback: []
      #   }

      _ ->
        buffer
    end
  end

  @doc """
  Erases parts of the current line based on the cursor position.
  Type can be :to_end, :to_beginning, or :all.
  Requires the cursor state for positioning.
  """
  @spec erase_in_line(t(), Raxol.Terminal.Cursor.Manager.t(), atom()) :: t()
  def erase_in_line(%__MODULE__{} = buffer, cursor, type) do
    # Access position directly from cursor struct
    {cursor_x, cursor_y} = cursor.position
    blank_cell = Cell.new()

    case type do
      :to_end ->
        erase_line_part(
          buffer,
          cursor_y,
          cursor_x,
          buffer.width - 1,
          blank_cell
        )

      :to_beginning ->
        erase_line_part(buffer, cursor_y, 0, cursor_x, blank_cell)

      :all ->
        erase_line_part(buffer, cursor_y, 0, buffer.width - 1, blank_cell)

      _ ->
        buffer
    end
  end

  # Helper to erase part of a single line
  defp erase_line_part(%__MODULE__{} = buffer, y, start_x, end_x, fill_cell) do
    if y >= 0 and y < buffer.height do
      start_col = max(0, start_x)
      end_col = min(buffer.width - 1, end_x)

      if start_col <= end_col do
        new_cells =
          List.update_at(buffer.cells, y, fn row ->
            Enum.reduce(start_col..end_col, row, fn x, acc_row ->
              List.replace_at(acc_row, x, fill_cell)
            end)
          end)

        %{buffer | cells: new_cells}
      else
        # Start is after end, do nothing
        buffer
      end
    else
      # Y out of bounds
      buffer
    end
  end

  @doc """
  Clears the entire screen buffer (excluding scrollback) by replacing all cells with new empty cells.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{width: width, height: height} = buffer) do
    new_cells = List.duplicate(List.duplicate(Cell.new(), width), height)
    %{buffer | cells: new_cells}
  end

  @doc """
  Inserts a specified number of blank characters at the given cursor position (x, y).
  Characters at and after the cursor position are shifted to the right.
  Characters shifted past the right margin are lost.
  The inserted characters use the provided style.
  """
  @spec insert_characters(
          t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  def insert_characters(%__MODULE__{} = buffer, {x, y}, count, style)
      when y >= 0 and y < buffer.height and x >= 0 and x < buffer.width and
             count > 0 do
    blank_cell = Cell.new(" ", style)
    # Create a list of 'count' blank cells
    blanks_to_insert = List.duplicate(blank_cell, count)

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        # Split the row at the insertion point
        {prefix, suffix} = Enum.split(row, x)
        # Determine how many suffix characters can remain after insertion
        remaining_suffix_length = max(0, buffer.width - x - count)
        # Take the necessary suffix chars and pad/truncate the row
        new_suffix = Enum.take(suffix, remaining_suffix_length)
        # Combine prefix, new blanks, and the remaining suffix
        prefix ++ blanks_to_insert ++ new_suffix
      end)

    %{buffer | cells: new_cells}
  end

  def insert_characters(buffer, _, _, _) do
    # No-op if position is invalid or count is zero
    buffer
  end

  @doc """
  Deletes a specified number of characters at the given cursor position (x, y).
  Characters after the deleted portion are shifted to the left.
  The vacated space at the end of the line is filled with blank cells (default style).
  """
  @spec delete_characters(
          t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer()
        ) :: t()
  def delete_characters(%__MODULE__{} = buffer, {x, y}, count)
      when y >= 0 and y < buffer.height and x >= 0 and x < buffer.width and
             count > 0 do
    # Use default style for trailing blanks
    blank_cell = Cell.new()

    new_cells =
      List.update_at(buffer.cells, y, fn row ->
        # Split the row at the deletion start point
        {prefix, rest} = Enum.split(row, x)
        # Drop the characters to be deleted from the rest
        # max(0, ...) ensures we don't drop negative count if count > length(rest)
        suffix_to_keep = Enum.drop(rest, max(0, count))
        # Calculate how many blanks are needed to fill the line
        blanks_needed =
          max(0, buffer.width - length(prefix) - length(suffix_to_keep))

        # Create the trailing blank cells
        trailing_blanks = List.duplicate(blank_cell, blanks_needed)
        # Combine prefix, remaining suffix, and trailing blanks
        prefix ++ suffix_to_keep ++ trailing_blanks
      end)

    %{buffer | cells: new_cells}
  end

  def delete_characters(buffer, _, _) do
    # No-op if position is invalid or count is zero
    buffer
  end

  @doc """
  Inserts `n` blank lines at the specified `start_y` row within the scroll region.
  Lines from `start_y` to the bottom of the scroll region are shifted down.
  Lines shifted below the scroll region are discarded.
  Handles `scroll_region` being nil (uses full buffer).
  """
  @spec insert_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  def insert_lines(%__MODULE__{} = buffer, start_y, n, scroll_region)
      when start_y >= 0 and n > 0 do
    # Determine scroll boundaries based on the passed-in scroll_region
    {scroll_start, scroll_end} =
      case scroll_region do
        {start, ending} -> {start, ending}
        nil -> {0, buffer.height - 1}
      end

    visible_lines_in_region = scroll_end - scroll_start + 1

    # Only proceed if start_y is within the scroll region
    if start_y >= scroll_start and start_y <= scroll_end do
      # Create the blank lines to insert
      blank_line = List.duplicate(Cell.new(), buffer.width)
      blank_lines_to_insert = List.duplicate(blank_line, n)

      # Get the lines currently within the scroll region
      scroll_region_cells = Enum.slice(buffer.cells, scroll_start..scroll_end)

      # Calculate the insertion index relative to the region start
      relative_insert_y = start_y - scroll_start

      # Split the region lines at the insertion point
      {lines_before_insert, lines_at_and_after_insert} =
        Enum.split(scroll_region_cells, relative_insert_y)

      # Determine how many lines from `lines_at_and_after_insert` to keep
      # We need to make space for `n` new lines.
      lines_to_keep_count =
        max(0, visible_lines_in_region - length(lines_before_insert) - n)

      lines_to_keep = Enum.take(lines_at_and_after_insert, lines_to_keep_count)

      # Combine the parts: lines before + new blank lines + kept lines
      new_region_content =
        lines_before_insert ++ blank_lines_to_insert ++ lines_to_keep

      # Ensure the new region content has the correct number of lines (it should, but safeguard)
      new_region_content =
        Enum.take(new_region_content, visible_lines_in_region)

      # Construct the new full cells list by replacing the scroll region content
      # scrollback unchanged by IL
      replace_scroll_region(
        buffer,
        scroll_start,
        scroll_end,
        new_region_content,
        buffer.scrollback
      )
    else
      # Insertion point is outside the scroll region, do nothing
      buffer
    end
  end

  # No-op if start_y is negative or n is zero or less
  def insert_lines(buffer, _, n, _) when n <= 0, do: buffer
  def insert_lines(buffer, start_y, _, _) when start_y < 0, do: buffer

  @doc """
  Converts the screen buffer content to a plain text string.
  """
  @spec get_content(t()) :: String.t()
  def get_content(%__MODULE__{} = buffer) do
    buffer.cells
    |> Enum.map(fn row ->
      row
      |> Enum.map(fn cell ->
        # Extract just the character content (ignore style information)
        cell.char
      end)
      |> Enum.join("")
      |> String.trim_trailing()
    end)
    |> Enum.join("\n")
  end

  # --- Modification Helpers ---
end
