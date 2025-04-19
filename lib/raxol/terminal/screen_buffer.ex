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
    unless is_number(width) and is_number(height) do
      Logger.warning(
        "Invalid dimensions provided to ScreenBuffer.new: width=#{inspect(width)}, height=#{inspect(height)}. Using defaults."
      )
    end

    %__MODULE__{
      cells:
        List.duplicate(List.duplicate(Cell.new(), actual_width), actual_height),
      scrollback: [],
      scrollback_limit: scrollback_limit,
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
  Scrolls the buffer up by the specified number of lines.
  """
  @spec scroll_up(t(), non_neg_integer()) :: t()
  def scroll_up(%__MODULE__{} = buffer, lines) when lines > 0 do
    {scroll_start, scroll_end} = get_scroll_region_boundaries(buffer)
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
  Scrolls the buffer down by the specified number of lines.
  """
  @spec scroll_down(t(), non_neg_integer()) :: t()
  def scroll_down(%__MODULE__{} = buffer, lines) when lines > 0 do
    {scroll_start, scroll_end} = get_scroll_region_boundaries(buffer)
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
      when new_width > 0 and new_height > 0 do
    # Create a new empty buffer of the target size
    new_cells =
      List.duplicate(List.duplicate(Cell.new(), new_width), new_height)

    # Determine the bounds to copy from the old buffer
    max_y_copy = min(buffer.height - 1, new_height - 1)
    max_x_copy = min(buffer.width - 1, new_width - 1)

    # Copy content from the old buffer to the new buffer
    copied_cells =
      Enum.reduce(0..max_y_copy, new_cells, fn y, acc_new_cells ->
        old_row = Enum.at(buffer.cells, y)
        new_row = Enum.at(acc_new_cells, y)

        updated_new_row =
          Enum.reduce(0..max_x_copy, new_row, fn x, acc_new_row ->
            old_cell = Enum.at(old_row, x)
            List.replace_at(acc_new_row, x, old_cell)
          end)

        List.replace_at(acc_new_cells, y, updated_new_row)
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
  Deletes `n` lines starting from the specified `start_y` within the scroll region.
  New blank lines are added at the bottom of the scroll region.
  """
  @spec delete_lines(t(), non_neg_integer(), non_neg_integer()) :: t()
  def delete_lines(%__MODULE__{} = buffer, start_y, n)
      when start_y >= 0 and n > 0 do
    {scroll_start, scroll_end} = get_scroll_region_boundaries(buffer)
    visible_lines = scroll_end - scroll_start + 1

    # Ensure deletion happens within the scroll region
    if start_y < scroll_start or start_y > scroll_end do
      buffer
    else
      # Calculate the effective number of lines to delete within the region
      lines_to_delete = min(n, scroll_end - start_y + 1)

      if lines_to_delete <= 0 do
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
  Gets a cell at the specified position.
  Returns a default cell if coordinates are out of bounds.
  """
  @spec get_cell(t(), integer(), integer()) :: Cell.t()
  def get_cell(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      Enum.at(buffer.cells, y) |> Enum.at(x)
    else
      Cell.new()
    end
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
end
