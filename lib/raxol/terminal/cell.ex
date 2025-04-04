defmodule Raxol.Terminal.Cell do
  @moduledoc """
  Terminal character cell module.
  
  This module handles the representation and manipulation of individual
  character cells in the terminal screen buffer, including:
  - Character content
  - Text attributes (color, style)
  - Cell state
  """

  @type t :: %__MODULE__{
    char: String.t(),
    attributes: map()
  }

  defstruct [
    :char,
    :attributes
  ]

  @doc """
  Creates a new empty cell.
  
  ## Examples
  
      iex> cell = Cell.new()
      iex> Cell.is_empty?(cell)
      true
  """
  def new(attributes \\ %{}) do
    %__MODULE__{
      char: "",
      attributes: attributes
    }
  end

  @doc """
  Creates a new cell with the given character and attributes.
  
  ## Examples
  
      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.get_char(cell)
      "A"
      iex> Cell.get_attribute(cell, :foreground)
      :red
  """
  def new(char, attributes) do
    %__MODULE__{
      char: char,
      attributes: attributes
    }
  end

  @doc """
  Gets the character content of a cell.
  
  ## Examples
  
      iex> cell = Cell.new("A")
      iex> Cell.get_char(cell)
      "A"
  """
  def get_char(%__MODULE__{} = cell) do
    cell.char
  end

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
  Gets an attribute value from a cell.
  
  ## Examples
  
      iex> cell = Cell.new("A", %{foreground: :red})
      iex> Cell.get_attribute(cell, :foreground)
      :red
  """
  def get_attribute(%__MODULE__{} = cell, key) do
    Map.get(cell.attributes, key)
  end

  @doc """
  Sets an attribute value in a cell.
  
  ## Examples
  
      iex> cell = Cell.new("A")
      iex> cell = Cell.set_attribute(cell, :foreground, :red)
      iex> Cell.get_attribute(cell, :foreground)
      :red
  """
  def set_attribute(%__MODULE__{} = cell, key, value) do
    %{cell | attributes: Map.put(cell.attributes, key, value)}
  end

  @doc """
  Removes an attribute from a cell.
  
  ## Examples
  
      iex> cell = Cell.new("A", %{foreground: :red})
      iex> cell = Cell.remove_attribute(cell, :foreground)
      iex> Cell.get_attribute(cell, :foreground)
      nil
  """
  def remove_attribute(%__MODULE__{} = cell, key) do
    %{cell | attributes: Map.delete(cell.attributes, key)}
  end

  @doc """
  Checks if a cell is empty (has no character content).
  
  ## Examples
  
      iex> cell = Cell.new()
      iex> Cell.is_empty?(cell)
      true
      iex> cell = Cell.new("A")
      iex> Cell.is_empty?(cell)
      false
  """
  def is_empty?(%__MODULE__{} = cell) do
    cell.char == ""
  end

  @doc """
  Merges attributes from another cell into this cell.
  
  ## Examples
  
      iex> cell1 = Cell.new("A", %{foreground: :red})
      iex> cell2 = Cell.new("B", %{background: :blue})
      iex> cell = Cell.merge_attributes(cell1, cell2)
      iex> Cell.get_attribute(cell, :foreground)
      :red
      iex> Cell.get_attribute(cell, :background)
      :blue
  """
  def merge_attributes(%__MODULE__{} = cell1, %__MODULE__{} = cell2) do
    %{cell1 | attributes: Map.merge(cell1.attributes, cell2.attributes)}
  end

  @doc """
  Creates a copy of a cell with new attributes.
  
  ## Examples
  
      iex> cell = Cell.new("A", %{foreground: :red})
      iex> new_cell = Cell.with_attributes(cell, %{background: :blue})
      iex> Cell.get_char(new_cell)
      "A"
      iex> Cell.get_attribute(new_cell, :foreground)
      :red
      iex> Cell.get_attribute(new_cell, :background)
      :blue
  """
  def with_attributes(%__MODULE__{} = cell, attributes) do
    %{cell | attributes: Map.merge(cell.attributes, attributes)}
  end

  @doc """
  Creates a copy of a cell with a new character.
  
  ## Examples
  
      iex> cell = Cell.new("A", %{foreground: :red})
      iex> new_cell = Cell.with_char(cell, "B")
      iex> Cell.get_char(new_cell)
      "B"
      iex> Cell.get_attribute(new_cell, :foreground)
      :red
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
      iex> Cell.get_attribute(copy, :foreground)
      :red
  """
  def copy(%__MODULE__{} = cell) do
    %__MODULE__{
      char: cell.char,
      attributes: Map.new(cell.attributes)
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
    cell1.char == cell2.char and
    Map.equal?(cell1.attributes, cell2.attributes)
  end
end 