defmodule Raxol.Terminal.Cell do
  @moduledoc """
  Terminal character cell module.

  This module handles the representation and manipulation of individual
  character cells in the terminal screen buffer, including:
  - Character content
  - Text attributes (color, style)
  - Cell state
  """

  alias Raxol.Terminal.ANSI.TextFormatting

  @type t :: %__MODULE__{
    char: String.t(),
    style: TextFormatting.text_style()
  }

  defstruct [
    :char,
    :style
  ]

  @doc """
  Creates a new cell with optional character and style.

  ## Examples

      iex> cell = Cell.new()
      iex> Cell.is_empty?(cell)
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
  def new() do
    %__MODULE__{
      char: " ",  # Use a space character for empty cells
      style: TextFormatting.new()
    }
  end

  def new(style) when not is_binary(style) do
    %__MODULE__{
      char: " ",  # Use a space character for empty cells
      style: style
    }
  end

  def new(char) when is_binary(char) do
    %__MODULE__{
      char: char,
      style: TextFormatting.new()
    }
  end

  def new(char, style) when is_binary(char) do
    %__MODULE__{
      char: char,
      style: style
    }
  end

  @doc """
  Gets the character content of a cell.

  ## Examples

      iex> cell = Cell.new("A")
      iex> Cell.get_char(cell)
      "A"
  """
  def get_char(%__MODULE__{char: char}), do: char

  @doc """
  Gets the text style of the cell.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.get_style(cell)
      %{foreground: :red}
  """
  def get_style(%__MODULE__{style: style}), do: style

  @doc """
  Sets the character content of a cell.

  ## Examples

      iex> cell = Cell.new()
      iex> cell = Cell.set_char(cell, "A")
      iex> Cell.get_char(cell)
      "A"
  """
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
  def set_style(%__MODULE__{} = cell, style) do
    %{cell | style: style}
  end

  @doc """
  Merges the cell's style with another style.

  ## Examples

      iex> cell1 = Cell.new("A", %{foreground: :red})
      iex> cell2 = Cell.new("B", %{background: :blue})
      iex> cell = Cell.merge_style(cell1, cell2)
      iex> Cell.get_style(cell)
      %{foreground: :red, background: :blue}
  """
  def merge_style(%__MODULE__{} = cell, style) do
    new_style = Map.merge(cell.style, style)
    %{cell | style: new_style}
  end

  @doc """
  Checks if the cell has a specific attribute.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.has_attribute?(cell, :foreground)
      true
  """
  def has_attribute?(%__MODULE__{style: style}, attribute) do
    Map.get(style, attribute, false)
  end

  @doc """
  Checks if the cell has a specific decoration.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.has_decoration?(cell, :bold)
      false
  """
  def has_decoration?(%__MODULE__{style: style}, decoration) do
    Map.get(style, decoration, false)
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
  def double_height?(%__MODULE__{style: style}), do: style.double_height != :none

  @doc """
  Checks if a cell is empty.

  A cell is considered empty if it contains a space character.

  ## Examples

      iex> cell = Cell.new()
      iex> Cell.is_empty?(cell)
      true

      iex> cell = Cell.new("A")
      iex> Cell.is_empty?(cell)
      false
  """
  def is_empty?(%__MODULE__{char: char}) do
    char == " "
  end

  @doc """
  Creates a copy of a cell with new attributes.

  ## Examples

      iex> cell = Cell.new("A", %{foreground: :red})
      iex> new_cell = Cell.with_attributes(cell, %{background: :blue})
      iex> Cell.get_char(new_cell)
      "A"
      iex> Cell.get_style(new_cell)
      %{foreground: :red, background: :blue}
  """
  def with_attributes(%__MODULE__{} = cell, attributes) do
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
      style: Map.new(cell.style)
    }
  end

  @doc """
  Compares two cells for equality.

  ## Examples

      iex> cell1 = Cell.new("A", %{foreground: :red})
      iex> cell2 = Cell.new("A", %{foreground: :red})
      iex> Cell.equals?(cell1, cell2)
      true
      iex> cell3 = Cell.new("B", %{foreground: :red})
      iex> Cell.equals?(cell1, cell3)
      false
  """
  def equals?(%__MODULE__{} = cell1, %__MODULE__{} = cell2) do
    cell1.char == cell2.char && cell1.style == cell2.style
  end
end
