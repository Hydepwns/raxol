defmodule Raxol.Terminal.Buffer.Cell do
  @moduledoc """
  Manages terminal cell operations and attributes.
  """

  defstruct [
    :char,
    :foreground,
    :background,
    :attributes,
    :hyperlink,
    :width
  ]

  @type t :: %__MODULE__{
          char: String.t(),
          foreground: integer(),
          background: integer(),
          attributes: map(),
          hyperlink: String.t() | nil,
          width: integer()
        }

  @doc """
  Creates a new cell with default settings.
  """
  def new(opts \\ []) do
    %__MODULE__{
      char: Keyword.get(opts, :char, " "),
      foreground: Keyword.get(opts, :foreground, 7),
      background: Keyword.get(opts, :background, 0),
      attributes: Keyword.get(opts, :attributes, %{}),
      hyperlink: Keyword.get(opts, :hyperlink, nil),
      width: Keyword.get(opts, :width, 1)
    }
  end

  @doc """
  Gets the cell's character.
  """
  def get_char(%__MODULE__{} = cell) do
    cell.char
  end

  @doc """
  Sets the cell's character.
  """
  def set_char(%__MODULE__{} = cell, char) when is_binary(char) do
    %{cell | char: char}
  end

  @doc """
  Gets the cell's foreground color.
  """
  def get_foreground(%__MODULE__{} = cell) do
    cell.foreground
  end

  @doc """
  Sets the cell's foreground color.
  """
  def set_foreground(%__MODULE__{} = cell, color) when is_integer(color) do
    %{cell | foreground: color}
  end

  @doc """
  Gets the cell's background color.
  """
  def get_background(%__MODULE__{} = cell) do
    cell.background
  end

  @doc """
  Sets the cell's background color.
  """
  def set_background(%__MODULE__{} = cell, color) when is_integer(color) do
    %{cell | background: color}
  end

  @doc """
  Gets the cell's attributes.
  """
  def get_attributes(%__MODULE__{} = cell) do
    cell.attributes
  end

  @doc """
  Sets the cell's attributes.
  """
  def set_attributes(%__MODULE__{} = cell, attributes)
      when is_map(attributes) do
    %{cell | attributes: attributes}
  end

  @doc """
  Gets the cell's hyperlink.
  """
  def get_hyperlink(%__MODULE__{} = cell) do
    cell.hyperlink
  end

  @doc """
  Sets the cell's hyperlink.
  """
  def set_hyperlink(%__MODULE__{} = cell, hyperlink)
      when is_binary(hyperlink) or is_nil(hyperlink) do
    %{cell | hyperlink: hyperlink}
  end

  @doc """
  Gets the cell's width.
  """
  def get_width(%__MODULE__{} = cell) do
    cell.width
  end

  @doc """
  Sets the cell's width.
  """
  def set_width(%__MODULE__{} = cell, width)
      when is_integer(width) and width > 0 do
    %{cell | width: width}
  end

  @doc """
  Checks if the cell is empty.
  """
  def empty?(%__MODULE__{} = cell) do
    cell.char == " "
  end

  @doc """
  Resets a cell to its default state.
  """
  def reset(%__MODULE__{} = _cell) do
    %__MODULE__{}
  end

  @doc """
  Copies attributes from one cell to another.
  """
  def copy_attributes(%__MODULE__{} = source, %__MODULE__{} = target) do
    %{
      target
      | foreground: source.foreground,
        background: source.background,
        attributes: source.attributes,
        hyperlink: source.hyperlink
    }
  end
end
