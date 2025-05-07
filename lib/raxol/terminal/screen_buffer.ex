defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Manages the terminal's screen buffer state (grid, scrollback, selection).
  Delegates operations to specialized modules in Raxol.Terminal.Buffer.*
  """

  @behaviour Raxol.Terminal.ScreenBufferBehaviour

  require Logger

  alias Raxol.Terminal.Cell
  # alias Raxol.Terminal.CharacterHandling # No longer directly used here
  # Used by Operations
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Selection
  alias Raxol.Terminal.Buffer.Scrollback
  alias Raxol.Terminal.Buffer.Operations
  alias Raxol.Terminal.Buffer.LineEditor
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.Buffer.Eraser

  defstruct [
    # The main grid of cells
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
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def new(width, height, scrollback_limit \\ 1000) do
    # Validation logic remains here as it's about initialization
    actual_width = if is_number(width) and width > 0, do: width, else: 80
    actual_height = if is_number(height) and height > 0, do: height, else: 24

    if !(is_number(width) and is_number(height)) do
      Logger.warning(
        "Invalid dimensions provided to ScreenBuffer.new: width=#{inspect(width)}, height=#{inspect(height)}. Using defaults."
      )
    end

    {valid_scrollback_limit, scrollback_warning} =
      cond do
        is_integer(scrollback_limit) and scrollback_limit >= 0 ->
          {scrollback_limit, nil}

        true ->
          warning =
            "Invalid scrollback_limit: #{inspect(scrollback_limit)}. Using default 1000."

          {1000, warning}
      end

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

  # === Delegated Functions ===

  # --- Writing --- (Delegated to Operations)
  @doc "Writes a character. See `Raxol.Terminal.Buffer.Operations.write_char/5`."
  @spec write_char(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          TextFormatting.text_style() | nil
        ) :: t()
  defdelegate write_char(buffer, x, y, char, style \\ nil), to: Operations

  @doc "Writes a string. See `Raxol.Terminal.Buffer.Operations.write_string/4`."
  @spec write_string(t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          t()
  defdelegate write_string(buffer, x, y, string), to: Operations

  # --- Scrolling --- (Delegated to Operations, uses Scrollback)
  @doc "Scrolls up. See `Raxol.Terminal.Buffer.Operations.scroll_up/3`."
  @spec scroll_up(
          t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  defdelegate scroll_up(buffer, lines, scroll_region \\ nil), to: Operations

  @doc "Scrolls down. See `Raxol.Terminal.Buffer.Operations.scroll_down/3`."
  @spec scroll_down(
          t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  defdelegate scroll_down(buffer, lines, scroll_region \\ nil), to: Operations

  # --- Scroll Region --- (Delegated to Operations)
  @doc "Sets scroll region. See `Raxol.Terminal.Buffer.Operations.set_scroll_region/3`."
  @spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate set_scroll_region(buffer, start_line, end_line), to: Operations

  @doc "Clears scroll region. See `Raxol.Terminal.Buffer.Operations.clear_scroll_region/1`."
  @spec clear_scroll_region(t()) :: t()
  defdelegate clear_scroll_region(buffer), to: Operations

  @doc "Gets scrollback size. See `Raxol.Terminal.Buffer.Scrollback.size/1`."
  @spec get_scroll_position(t()) :: non_neg_integer()
  defdelegate get_scroll_position(buffer), to: Scrollback, as: :size

  @doc "Gets scroll region boundaries. See `Raxol.Terminal.Buffer.Operations.get_scroll_region_boundaries/1`."
  @spec get_scroll_region_boundaries(t()) ::
          {non_neg_integer(), non_neg_integer()}
  defdelegate get_scroll_region_boundaries(buffer), to: Operations

  # --- Selection --- (Delegated to Selection)
  @doc "Starts selection. See `Raxol.Terminal.Buffer.Selection.start/3`."
  @spec start_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate start_selection(buffer, x, y), to: Selection, as: :start

  @doc "Updates selection. See `Raxol.Terminal.Buffer.Selection.update/3`."
  @spec update_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate update_selection(buffer, x, y), to: Selection, as: :update

  @doc "Gets selected text. See `Raxol.Terminal.Buffer.Selection.get_text/1`."
  @spec get_selection(t()) :: String.t()
  defdelegate get_selection(buffer), to: Selection, as: :get_text

  @doc "Checks if in selection. See `Raxol.Terminal.Buffer.Selection.contains?/3`."
  @spec in_selection?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  defdelegate in_selection?(buffer, x, y), to: Selection, as: :contains?

  @doc "Gets selection boundaries. See `Raxol.Terminal.Buffer.Selection.get_boundaries/1`."
  @spec get_selection_boundaries(t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer(),
           non_neg_integer()}
          | nil
  defdelegate get_selection_boundaries(buffer),
    to: Selection,
    as: :get_boundaries

  @doc "Gets text in region. See `Raxol.Terminal.Buffer.Selection.get_text_in_region/5`."
  @spec get_text_in_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: String.t()
  defdelegate get_text_in_region(buffer, start_x, start_y, end_x, end_y),
    to: Selection

  @doc """
  Checks if the buffer contains only default cells.
  """
  @spec is_empty?(t()) :: boolean()
  def is_empty?(buffer) do
    # Use Cell.is_empty? for a more accurate check
    Enum.all?(buffer.cells, fn row ->
      Enum.all?(row, &Cell.is_empty?/1)
    end)
  end

  # --- Resizing & Dimensions --- (Delegated to Operations)
  @doc "Resizes buffer. See `Raxol.Terminal.Buffer.Operations.resize/3`."
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate resize(buffer, new_width, new_height), to: Operations

  @doc "Gets width. See `Raxol.Terminal.Buffer.Operations.get_width/1`."
  @spec get_width(t()) :: non_neg_integer()
  defdelegate get_width(buffer), to: Operations

  @doc "Gets height. See `Raxol.Terminal.Buffer.Operations.get_height/1`."
  @spec get_height(t()) :: non_neg_integer()
  defdelegate get_height(buffer), to: Operations

  @doc "Gets dimensions. See `Raxol.Terminal.Buffer.Operations.get_dimensions/1`."
  @spec get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_dimensions(buffer), to: Operations

  # --- Cell/Line Access --- (Delegated to Operations)
  @doc "Gets line. See `Raxol.Terminal.Buffer.Operations.get_line/2`."
  @spec get_line(t(), non_neg_integer()) :: list(Cell.t()) | nil
  defdelegate get_line(buffer, line_index), to: Operations

  @doc "Gets cell. See `Raxol.Terminal.Buffer.Operations.get_cell/3`."
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  defdelegate get_cell(buffer, x, y), to: Operations

  @doc "Gets cell at. See `Raxol.Terminal.Buffer.Operations.get_cell_at/3`."
  @spec get_cell_at(t(), non_neg_integer(), non_neg_integer()) :: Cell.t() | nil
  defdelegate get_cell_at(buffer, x, y), to: Operations

  # --- Clearing/Erasing --- (Delegated to Eraser)
  @doc "Clears region. See `Raxol.Terminal.Buffer.Eraser.clear_region/6`."
  @spec clear_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate clear_region(buffer, start_x, start_y, end_x, end_y, default_style),
    to: Eraser

  @doc "Erases in display. See `Raxol.Terminal.Buffer.Eraser.erase_in_display/4`."
  @spec erase_in_display(
          t(),
          {non_neg_integer(), non_neg_integer()},
          atom(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate erase_in_display(buffer, cursor_pos, type, default_style), to: Eraser

  @doc "Erases in line. See `Raxol.Terminal.Buffer.Eraser.erase_in_line/4`."
  @spec erase_in_line(
          t(),
          {non_neg_integer(), non_neg_integer()},
          atom(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate erase_in_line(buffer, cursor_pos, type, default_style), to: Eraser

  @doc "Clears buffer. See `Raxol.Terminal.Buffer.Eraser.clear_screen/2`."
  @spec clear(t(), TextFormatting.text_style()) :: t()
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate clear(buffer, default_style), to: Eraser, as: :clear_screen

  # --- Deleting --- (Delegated to LineEditor/CharEditor)
  @doc """
  Deletes `n` lines starting at `start_y`.
  Optionally operates only within the given `scroll_region` {top, bottom}.
  """
  @spec delete_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  def delete_lines(%__MODULE__{} = buffer, start_y, count, default_style, scroll_region \\ nil)
      when start_y >= 0 and count > 0 do
    {region_top, region_bottom} =
      case scroll_region do
        {t, b} when is_integer(t) and t >= 0 and is_integer(b) and b >= t and b < buffer.height ->
          {t, b}
        _ -> # No valid region provided, use full buffer height
          {0, buffer.height - 1}
      end

    # Ensure the operation start is within the effective region
    if start_y >= region_top && start_y <= region_bottom do
      # Calculate how many lines to actually delete within the region
      lines_in_region_from_start = region_bottom - start_y + 1
      effective_count = min(count, lines_in_region_from_start)

      blank_line = List.duplicate(%Cell{char: " ", style: default_style}, buffer.width)
      blank_lines = List.duplicate(blank_line, effective_count)

      # Extract the lines within the scroll region
      region_cells = Enum.slice(buffer.cells, region_top..(region_top + (region_bottom - region_top)))
      # Calculate relative start within the extracted region
      relative_start_y = start_y - region_top

      # Split the region lines
      {region_before, region_after_inclusive} = Enum.split(region_cells, relative_start_y)
      # Keep lines after deletion within the region
      region_after_kept = Enum.drop(region_after_inclusive, effective_count)

      # Combine parts within the region, adding blank lines at the end *of the region*
      new_region_cells = region_before ++ region_after_kept ++ blank_lines

      # Splice the modified region back into the full buffer cells
      cells_before_region = Enum.slice(buffer.cells, 0, region_top)
      cells_after_region = Enum.slice(buffer.cells, region_bottom + 1, buffer.height - (region_bottom + 1))
      final_cells = cells_before_region ++ new_region_cells ++ cells_after_region

      %{buffer | cells: final_cells}
    else
      # Start is outside the region, no operation
      buffer
    end
  end

  def delete_lines(buffer, _, _, _, _), do: buffer # No-op for invalid input

  @doc """
  Deletes `count` characters starting at `{row, col}`.

  Characters to the right are shifted left.
  Blank cells are inserted at the end of the line.

  Delegates to `CharEditor.delete_characters/5`. Requires default_style.
  """
  @spec delete_characters(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate delete_characters(buffer, row, col, count, default_style), to: CharEditor

  # --- Inserting --- (Delegated to CharEditor/LineEditor)
  @doc """
  Inserts `count` blank lines at `row`.

  Lines from `row` down are shifted down.
  Lines shifted off the bottom are discarded.

  Delegates to `LineEditor.insert_lines/4`. Requires default_style.
  """
  @spec insert_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate insert_lines(buffer, row, count, default_style), to: LineEditor

  @doc """
  Inserts `count` blank characters at `{row, col}`.

  Characters from `col` right are shifted right.
  Characters shifted off the end of the line are discarded.

  Delegates to `CharEditor.insert_characters/5`. Requires default_style.
  """
  @spec insert_characters(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: t()
  defdelegate insert_characters(buffer, row, col, count, default_style), to: CharEditor

  # --- Diffing & Updating --- (Delegated to Operations)
  @doc "Calculates diff. See `Raxol.Terminal.Buffer.Operations.diff/2`."
  @spec diff(t(), list({non_neg_integer(), non_neg_integer(), map()})) ::
          list({non_neg_integer(), non_neg_integer(), map()})
  defdelegate diff(buffer, changes), to: Operations

  @doc "Updates buffer from changes. See `Raxol.Terminal.Buffer.Operations.update/2`."
  @spec update(
          t(),
          list({non_neg_integer(), non_neg_integer(), Cell.t() | map()})
        ) :: t()
  defdelegate update(buffer, changes), to: Operations

  # --- Content Retrieval --- (Delegated to Operations)
  @doc "Gets content as string. See `Raxol.Terminal.Buffer.Operations.get_content/1`."
  @spec get_content(t()) :: String.t()
  defdelegate get_content(buffer), to: Operations

  # --- Deprecated --- (Keep temporarily? Or remove?) ---
  # @doc false
  # @deprecated "Use in_selection?/3 instead"
  # def is_in_selection?(buffer, x, y), do: in_selection?(buffer, x, y)

  # Note: Removed get_changes/2 as diff/2 now handles the {x,y,map} format directly.
end
