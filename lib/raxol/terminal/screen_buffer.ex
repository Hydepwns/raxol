defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Manages the terminal's screen buffer state (grid, scrollback, selection).
  Delegates operations to specialized modules in Raxol.Terminal.Buffer.*
  """

  require Logger

  alias Raxol.Terminal.Cell
  # alias Raxol.Terminal.CharacterHandling # No longer directly used here
  # Used by Operations
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Selection
  alias Raxol.Terminal.Buffer.Scrollback
  alias Raxol.Terminal.Buffer.Operations

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

  # --- Resizing & Dimensions --- (Delegated to Operations)
  @doc "Resizes buffer. See `Raxol.Terminal.Buffer.Operations.resize/3`."
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  defdelegate resize(buffer, new_width, new_height), to: Operations

  @doc "Gets width. See `Raxol.Terminal.Buffer.Operations.get_width/1`."
  @spec get_width(t()) :: non_neg_integer()
  defdelegate get_width(buffer), to: Operations

  @doc "Gets height. See `Raxol.Terminal.Buffer.Operations.get_height/1`."
  @spec get_height(t()) :: non_neg_integer()
  defdelegate get_height(buffer), to: Operations

  @doc "Gets dimensions. See `Raxol.Terminal.Buffer.Operations.get_dimensions/1`."
  @spec get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
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

  # --- Clearing/Erasing --- (Delegated to Operations)
  @doc "Clears region. See `Raxol.Terminal.Buffer.Operations.clear_region/5`."
  @spec clear_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
  defdelegate clear_region(buffer, start_x, start_y, end_x, end_y),
    to: Operations

  @doc "Erases in display. See `Raxol.Terminal.Buffer.Operations.erase_in_display/3`."
  @spec erase_in_display(t(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          t()
  defdelegate erase_in_display(buffer, cursor_pos, type), to: Operations

  @doc "Erases in line. See `Raxol.Terminal.Buffer.Operations.erase_in_line/3`."
  @spec erase_in_line(t(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          t()
  defdelegate erase_in_line(buffer, cursor_pos, type), to: Operations

  @doc "Clears buffer. See `Raxol.Terminal.Buffer.Operations.clear/1`."
  @spec clear(t()) :: t()
  defdelegate clear(buffer), to: Operations

  # --- Deleting --- (Delegated to Operations)
  @doc "Deletes lines. See `Raxol.Terminal.Buffer.Operations.delete_lines/4`."
  @spec delete_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  defdelegate delete_lines(buffer, start_y, n, scroll_region), to: Operations

  @doc "Deletes characters. See `Raxol.Terminal.Buffer.Operations.delete_characters/3`."
  @spec delete_characters(
          t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer()
        ) :: t()
  defdelegate delete_characters(buffer, pos, count), to: Operations

  # --- Inserting --- (Delegated to Operations)
  @doc "Inserts characters. See `Raxol.Terminal.Buffer.Operations.insert_characters/4`."
  @spec insert_characters(
          t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer(),
          TextFormatting.text_style() | nil
        ) :: t()
  defdelegate insert_characters(buffer, pos, count, style \\ nil),
    to: Operations

  @doc "Inserts lines. See `Raxol.Terminal.Buffer.Operations.insert_lines/4`."
  @spec insert_lines(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: t()
  defdelegate insert_lines(buffer, start_y, n, scroll_region), to: Operations

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
