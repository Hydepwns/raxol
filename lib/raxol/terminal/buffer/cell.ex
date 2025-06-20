defmodule Raxol.Terminal.Buffer.Cell do
  @moduledoc """
  Manages terminal cell operations and attributes.
  """

  alias Raxol.Terminal.ANSI.TextFormatting

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
          foreground: integer() | atom() | String.t(),
          background: integer() | atom() | String.t(),
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
  Creates a new cell with the specified character and style.
  """
  def new(char, style) when is_binary(char) and is_map(style) do
    %__MODULE__{
      char: char,
      foreground: extract_foreground(style),
      background: extract_background(style),
      attributes: extract_attributes(style),
      hyperlink: extract_hyperlink(style),
      width: extract_width(style)
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

  @doc """
  Validates a cell's data.
  Returns true if the cell is valid, false otherwise.
  """
  def valid?(%__MODULE__{} = cell) do
    valid_char?(cell.char) and
      valid_color?(cell.foreground) and
      valid_color?(cell.background) and
      valid_attributes?(cell.attributes)
  end

  def valid?(_), do: false

  defp valid_char?(char) when is_binary(char) do
    String.length(char) == 1
  end

  defp valid_char?(_), do: false

  defp valid_color?(color) when is_atom(color) do
    color in [
      :default,
      :black,
      :red,
      :green,
      :yellow,
      :blue,
      :magenta,
      :cyan,
      :white
    ]
  end

  defp valid_color?(color) when is_binary(color) do
    String.match?(color, ~r/^#[0-9A-Fa-f]{6}$/)
  end

  defp valid_color?(color) when is_integer(color) do
    color >= 0 and color <= 255
  end

  defp valid_color?(_), do: false

  defp valid_attributes?(attrs) when is_map(attrs) do
    Enum.all?(attrs, fn {key, value} ->
      key in [:bold, :italic, :underline, :strikethrough] and
        is_boolean(value)
    end)
  end

  defp valid_attributes?(_), do: false

  defp extract_foreground(style) do
    case Map.get(style, :foreground) do
      nil ->
        case style do
          %{foreground: fg} when not is_nil(fg) -> fg
          _ -> 7  # Default white
        end
      fg -> fg
    end
  end

  defp extract_background(style) do
    case Map.get(style, :background) do
      nil ->
        case style do
          %{background: bg} when not is_nil(bg) -> bg
          _ -> 0  # Default black
        end
      bg -> bg
    end
  end

  defp extract_attributes(style) do
    case Map.get(style, :attributes) do
      nil -> %{}
      attrs -> attrs
    end
  end

  defp extract_hyperlink(style) do
    case Map.get(style, :hyperlink) do
      nil ->
        case style do
          %{hyperlink: link} -> link
          _ -> nil
        end
      link -> link
    end
  end

  defp extract_width(style) do
    case Map.get(style, :width) do
      nil ->
        case style do
          %{width: w} when not is_nil(w) -> w
          _ -> 1
        end
      w -> w
    end
  end
end
