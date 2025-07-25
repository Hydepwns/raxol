defmodule Raxol.Terminal.Cell do
  @moduledoc """
  Terminal character cell module.

  This module handles the representation and manipulation of individual
  character cells in the terminal screen buffer, including:
  - Character content
  - Text attributes (color, style)
  - Cell state
  """

  import Raxol.Guards
  alias Raxol.Terminal.ANSI.TextFormatting

  @typedoc """
  Text style for a terminal cell. See `Raxol.Terminal.ANSI.TextFormatting.text_style/0` for details.
  """
  @type style :: TextFormatting.text_style()

  @type t :: %__MODULE__{
          char: String.t() | nil,
          style: TextFormatting.text_style() | nil,
          dirty: boolean(),
          wide_placeholder: boolean(),
          sixel: boolean()
        }

  defstruct [
    :char,
    :style,
    :dirty,
    wide_placeholder: false,
    sixel: false
  ]

  @doc """
  Creates a new cell with optional character and style.

  ## Examples

      iex> cell = Cell.new()
      iex> Cell.empty?(cell)
      true

      iex> cell = Cell.new("A")
      iex> Cell.get_char(cell)
      "A"

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.get_char(cell)
      "A"
      iex> Cell.get_style(cell)
      %{foreground: :red}
  """
  @spec new(String.t() | nil, TextFormatting.text_style() | nil) :: t()
  def new(char \\ " ", style \\ TextFormatting.new()) do
    %__MODULE__{
      char: char || " ",
      style: style,
      dirty: false,
      wide_placeholder: false,
      sixel: false
    }
  end

  @doc """
  Creates a new cell representing the second half of a wide character.
  Inherits the style from the primary cell.
  """
  def new_wide_placeholder(style) do
    %__MODULE__{
      # Placeholder has no visible char
      char: " ",
      style: style,
      dirty: true,
      wide_placeholder: true,
      sixel: false
    }
  end

  @doc """
  Returns the character of the cell.
  """
  @spec get_char(t()) :: String.t() | char()
  def get_char(%__MODULE__{char: char}), do: char

  @doc """
  Gets the text style of the cell.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.get_style(cell)
      %{foreground: :red}
  """
  @spec get_style(t()) :: TextFormatting.text_style() | nil
  def get_style(%__MODULE__{style: style}), do: style

  @doc """
  Gets the cell's foreground color (compatibility function).
  """
  def fg(%__MODULE__{style: style}) do
    style.foreground
  end

  @doc """
  Gets the cell's background color (compatibility function).
  """
  def bg(%__MODULE__{style: style}) do
    style.background
  end

  @doc """
  Sets the character content of a cell.

  ## Examples

      iex> cell = Cell.new()
      iex> cell = Cell.set_char(cell, "A")
      iex> Cell.get_char(cell)
      "A"
  """
  @spec set_char(t(), String.t()) :: t()
  def set_char(%__MODULE__{} = cell, char) do
    %{cell | char: char}
  end

  @doc """
  Sets the text style of the cell.

  ## Examples

      iex> cell = Cell.new("A")
      iex> cell = Cell.set_style(cell, %{foreground: :red})
      iex> Cell.get_style(cell)
      %{foreground: :red}
  """
  @spec set_style(t(), TextFormatting.text_style() | nil) :: t()
  def set_style(%__MODULE__{} = cell, style) do
    %{cell | style: style}
  end

  @doc """
  Merges a given style map into the cell's style.

  Only non-default attributes from the `style` map will overwrite existing attributes
  in the cell's style. This prevents merging default values (like `bold: false`)
  and unintentionally removing existing attributes.

  ## Examples

      iex> initial_style = TextFormatting.new() |> TextFormatting.apply_attribute(:bold) # %{bold: true, ...}
      iex> merge_style = TextFormatting.new() |> TextFormatting.apply_attribute(:underline) # %{underline: true, bold: false, ...}
      iex> cell = Cell.new("A", initial_style)
      iex> merged_cell = Cell.merge_style(cell, merge_style)
      iex> Cell.get_style(merged_cell)
      %{bold: true, underline: true} # Note: :bold remains, :underline added
  """
  def merge_style(%__MODULE__{} = cell, style_to_merge)
      when is_struct(style_to_merge, TextFormatting.Core) do
    default_style = TextFormatting.Core.new()

    # Convert both styles to maps for easier manipulation
    cell_style_map = Map.from_struct(cell.style)
    merge_style_map = Map.from_struct(style_to_merge)
    default_style_map = Map.from_struct(default_style)

    # Iterate through the style map we want to merge in.
    # Only apply the attribute if its value is different from the default.
    final_style_map =
      Enum.reduce(merge_style_map, cell_style_map, fn {key, value}, acc_style ->
        if Map.get(default_style_map, key) != value do
          Map.put(acc_style, key, value)
        else
          acc_style
        end
      end)

    # Convert back to TextFormatting.Core struct using new() function
    final_style = TextFormatting.Core.new(final_style_map)
    %{cell | style: final_style}
  end

  def merge_style(%__MODULE__{} = cell, style_to_merge)
      when map?(style_to_merge) do
    # Handle plain maps by converting to TextFormatting.Core struct first
    style_struct = TextFormatting.Core.new(style_to_merge)
    merge_style(cell, style_struct)
  end

  @doc """
  Checks if the cell has a specific attribute.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.has_attribute?(cell, :foreground)
      true
  """
  def has_attribute?(%__MODULE__{style: style}, attribute) do
    Map.get(Map.from_struct(style), attribute, false)
  end

  @doc """
  Checks if the cell has a specific decoration.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.has_decoration?(cell, :bold)
      false
  """
  def has_decoration?(%__MODULE__{style: style}, decoration) do
    Map.get(Map.from_struct(style), decoration, false)
  end

  @doc """
  Checks if the cell is in double-width mode.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.double_width?(cell)
      false
  """
  def double_width?(%__MODULE__{style: style}), do: style.double_width

  @doc """
  Checks if the cell is in double-height mode.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.double_height?(cell)
      false
  """
  def double_height?(%__MODULE__{style: style}),
    do: style.double_height != :none

  @doc """
  Checks if the cell is empty.

  ## Examples

      iex> cell = Cell.new()
      iex> Cell.empty?(cell)
      true

      iex> cell = Cell.new("A")
      iex> Cell.empty?(cell)
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{char: char, style: style}) do
    (char == nil or char == "" or char == " ") and style == TextFormatting.new()
  end

  @doc """
  Creates a copy of a cell with new attributes applied.

  Accepts a map of attributes or a list of attribute atoms.
  If a list is provided, the attributes are applied sequentially, starting from the cell's *existing* style.

  ## Examples

      iex> cell = Cell.new("A", %{bold: true})
      iex> new_cell = Cell.with_attributes(cell, %{underline: true}) # Using a map
      iex> Cell.get_style(new_cell)
      %{bold: true, underline: true} # Merged

      iex> cell = Cell.new("B", %{bold: true})
      iex> new_cell = Cell.with_attributes(cell, [:underline, :reverse]) # Using a list
      iex> Cell.get_style(new_cell)
      %{bold: true, underline: true, reverse: true} # Original bold + list applied

  """
  def with_attributes(%__MODULE__{} = cell, attributes)
      when list?(attributes) do
    # Apply each attribute to the cell's existing style
    new_style =
      Enum.reduce(attributes, cell.style, fn attribute, acc_style ->
        TextFormatting.Attributes.apply_attribute(acc_style, attribute)
      end)

    %{cell | style: new_style}
  end

  def with_attributes(%__MODULE__{} = cell, attributes)
      when map?(attributes) do
    # When merging a map, use the refined merge_style logic
    merge_style(cell, attributes)
  end

  @doc """
  Creates a copy of a cell with a new character.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> new_cell = Cell.with_char(cell, "B")
      iex> Cell.get_char(new_cell)
      "B"
      iex> Cell.get_style(new_cell)
      %{foreground: :red}
  """
  def with_char(%__MODULE__{} = cell, char) do
    %{cell | char: char}
  end

  @doc """
  Creates a deep copy of a cell.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> copy = Cell.copy(cell)
      iex> Cell.get_char(copy)
      "A"
      iex> Cell.get_style(copy)
      %{foreground: :red}
  """
  def copy(%__MODULE__{} = cell) do
    %__MODULE__{
      char: cell.char,
      style: cell.style,
      dirty: cell.dirty,
      wide_placeholder: cell.wide_placeholder
    }
  end

  @doc """
  Compares two cells for equality.

  Cells are considered equal if they have the same character and the same style map.
  Handles comparison with `nil`.

  ## Examples
      iex> style1 = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
      iex> style2 = TextFormatting.new() |> TextFormatting.apply_attribute(:bold)
      iex> style3 = TextFormatting.new() |> TextFormatting.apply_attribute(:underline)
      iex> cell1 = Cell.new("A", style1)
      iex> cell2 = Cell.new("A", style2) # Same char and style attributes
      iex> cell3 = Cell.new("B", style1) # Different char
      iex> cell4 = Cell.new("A", style3) # Different style
      iex> Cell.equals?(cell1, cell2)
      true
      iex> Cell.equals?(cell1, cell3)
      false
      iex> Cell.equals?(cell1, cell4)
      false
      iex> Cell.equals?(cell1, nil)
      false
      iex> Cell.equals?(nil, cell1)
      false
      iex> Cell.equals?(nil, nil)
      true
  """
  def equals?(%__MODULE__{} = cell1, %__MODULE__{} = cell2) do
    cell1.char == cell2.char && cell1.style == cell2.style &&
      cell1.wide_placeholder == cell2.wide_placeholder
  end

  def equals?(nil, nil), do: true
  def equals?(_, nil), do: false
  def equals?(nil, _), do: false

  @doc """
  Creates a Cell struct from a map representation, typically from rendering.
  Expects a map like %{char: integer_codepoint, style: map, wide_placeholder: boolean | nil}.
  Returns nil if the map is invalid.
  """
  @spec from_map(map()) :: t() | nil
  def from_map(%{char: char_code, style: style} = map)
      when integer?(char_code) and map?(style) do
    # Convert integer code point back to string for storing in the struct
    char_str = <<char_code::utf8>>
    wide_placeholder = Map.get(map, :wide_placeholder, false)

    %__MODULE__{
      char: char_str,
      style: style,
      dirty: true,
      wide_placeholder: wide_placeholder
    }
  end

  def from_map(_other_map) do
    # Log warning or handle error? For now, return nil.
    nil
  end

  @doc """
  Creates an empty cell.
  """
  @spec empty() :: t()
  def empty, do: new()
end
