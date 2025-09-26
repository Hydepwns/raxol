defmodule Raxol.Terminal.ScreenBuffer.DataAdapter do
  @moduledoc """
  Data structure adapter for ScreenBuffer operations.

  Provides bidirectional conversion between the two buffer formats:
  - ScreenBuffer.Core format: `:cells` (list of lists of Cell structs)
  - LineOperations format: `:lines` (map with integer keys to line lists)

  This adapter allows seamless interoperability between different buffer
  operation layers without requiring architectural changes.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Convert buffer from cells format to lines format.

  Transforms `buffer.cells` (list of lists) into a `:lines` map
  where keys are row indices and values are cell lists.
  """
  @spec cells_to_lines(map()) :: map()
  def cells_to_lines(buffer) when is_map(buffer) do
    case Map.get(buffer, :cells) do
      nil ->
        # Already has lines format or invalid buffer
        buffer

      cells when is_list(cells) ->
        lines_map =
          cells
          |> Enum.with_index()
          |> Enum.into(%{}, fn {line_cells, index} -> {index, line_cells} end)

        Map.put(buffer, :lines, lines_map)

      _ ->
        # Invalid cells format
        buffer
    end
  end

  @doc """
  Convert buffer from lines format back to cells format.

  Transforms `:lines` map back into `buffer.cells` (list of lists).
  """
  @spec lines_to_cells(map(), map()) :: map()
  def lines_to_cells(buffer, lines_map) when is_map(buffer) and is_map(lines_map) do
    height = Map.get(buffer, :height, 24)

    cells =
      0..(height - 1)
      |> Enum.map(fn row_index ->
        Map.get(lines_map, row_index, [])
      end)

    buffer
    |> Map.put(:cells, cells)
    |> Map.delete(:lines)  # Remove temporary lines map
  end

  @doc """
  Execute an operation function with the buffer temporarily in lines format.

  This is the key function that allows LineOperations to work with
  ScreenBuffer.Core structures without permanent conversion.

  The operation function can return either:
  - A modified buffer map
  - A tuple where the second element is the modified buffer map
  """
  @spec with_lines_format(map(), (map() -> map() | tuple())) :: map() | tuple()
  def with_lines_format(buffer, operation_fn) when is_map(buffer) and is_function(operation_fn, 1) do
    # Convert to lines format
    buffer_with_lines = cells_to_lines(buffer)

    # Execute operation
    result = operation_fn.(buffer_with_lines)

    # Handle different return types
    case result do
      {data, result_buffer} when is_map(result_buffer) ->
        # Operation returned a tuple with buffer as second element
        case Map.get(result_buffer, :lines) do
          lines_map when is_map(lines_map) ->
            converted_buffer = lines_to_cells(result_buffer, lines_map)
            {data, converted_buffer}

          _ ->
            {data, result_buffer}
        end

      result_buffer when is_map(result_buffer) ->
        # Operation returned just a buffer
        case Map.get(result_buffer, :lines) do
          lines_map when is_map(lines_map) ->
            lines_to_cells(result_buffer, lines_map)

          _ ->
            # Operation didn't modify lines, return as-is
            result_buffer
        end

      other ->
        # Return as-is for any other case
        other
    end
  end

  @doc """
  Check if buffer uses cells format (list of lists).
  """
  @spec has_cells_format?(map()) :: boolean()
  def has_cells_format?(buffer) when is_map(buffer) do
    case Map.get(buffer, :cells) do
      cells when is_list(cells) -> true
      _ -> false
    end
  end

  @doc """
  Check if buffer uses lines format (map).
  """
  @spec has_lines_format?(map()) :: boolean()
  def has_lines_format?(buffer) when is_map(buffer) do
    case Map.get(buffer, :lines) do
      lines when is_map(lines) -> true
      _ -> false
    end
  end

  @doc """
  Get a line from buffer regardless of format.
  """
  @spec get_line(map(), integer(), list()) :: list()
  def get_line(buffer, y, default) when is_map(buffer) and is_integer(y) do
    cond do
      has_lines_format?(buffer) ->
        Map.get(buffer.lines, y, default)

      has_cells_format?(buffer) ->
        if y >= 0 and y < length(buffer.cells) do
          Enum.at(buffer.cells, y, default)
        else
          default
        end

      true ->
        default
    end
  end

  @doc """
  Set a line in buffer regardless of format.
  """
  @spec set_line(map(), integer(), list()) :: map()
  def set_line(buffer, y, line) when is_map(buffer) and is_integer(y) and is_list(line) do
    cond do
      has_lines_format?(buffer) ->
        lines = Map.put(buffer.lines, y, line)
        %{buffer | lines: lines}

      has_cells_format?(buffer) ->
        if y >= 0 and y < length(buffer.cells) do
          cells = List.replace_at(buffer.cells, y, line)
          %{buffer | cells: cells}
        else
          buffer
        end

      true ->
        # Neither format, assume cells and create
        height = Map.get(buffer, :height, 24)
        width = Map.get(buffer, :width, 80)
        default_style = Map.get(buffer, :default_style, %TextFormatting{})

        # Create empty cells structure
        cells = create_empty_cells(width, height, default_style)
        updated_cells = if y >= 0 and y < height do
          List.replace_at(cells, y, line)
        else
          cells
        end

        Map.put(buffer, :cells, updated_cells)
    end
  end

  @doc """
  Create empty cells structure for initialization.
  """
  @spec create_empty_cells(integer(), integer(), map()) :: list(list())
  def create_empty_cells(width, height, default_style) do
    empty_line = create_empty_line(width, default_style)
    List.duplicate(empty_line, height)
  end

  @doc """
  Create an empty line with the specified width and style.
  """
  @spec create_empty_line(integer(), map()) :: list()
  def create_empty_line(width, default_style) do
    blank_cell = %Cell{
      char: " ",
      style: default_style || %TextFormatting{},
      dirty: false,
      wide_placeholder: false,
      sixel: false
    }

    List.duplicate(blank_cell, width)
  end
end