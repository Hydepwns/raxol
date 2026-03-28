defmodule Raxol.Terminal.StyleBuffer do
  @moduledoc """
  Manages terminal style state and operations.
  This module handles text attributes, colors, and formatting for terminal output.
  """

  @type style :: %{
          foreground: String.t() | nil,
          background: String.t() | nil,
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          attributes: [atom()]
        }

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type region :: {position(), position()}

  @type t :: %__MODULE__{
          current_style: style(),
          default_style: style(),
          style_map: %{position() => style()},
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  defstruct current_style: %{
              foreground: nil,
              background: nil,
              bold: false,
              italic: false,
              underline: false,
              attributes: []
            },
            default_style: %{
              foreground: nil,
              background: nil,
              bold: false,
              italic: false,
              underline: false,
              attributes: []
            },
            style_map: %{},
            width: 80,
            height: 24

  @doc """
  Creates a new style buffer with the given dimensions.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) do
    default_style = %{
      foreground: nil,
      background: nil,
      bold: false,
      italic: false,
      underline: false,
      attributes: []
    }

    %__MODULE__{
      current_style: default_style,
      default_style: default_style,
      style_map: %{},
      width: width,
      height: height
    }
  end

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(t(), String.t()) :: t()
  def set_foreground(buffer, color) do
    %{buffer | current_style: Map.put(buffer.current_style, :foreground, color)}
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(t(), String.t()) :: t()
  def set_background(buffer, color) do
    %{buffer | current_style: Map.put(buffer.current_style, :background, color)}
  end

  @doc """
  Sets text attributes (list of atoms).
  """
  @spec set_attributes(t(), [atom()]) :: t()
  def set_attributes(buffer, attrs) when is_list(attrs) do
    %{buffer | current_style: Map.put(buffer.current_style, :attributes, attrs)}
  end

  @doc """
  Gets the current style.
  """
  @spec get_style(t()) :: style()
  def get_style(%__MODULE__{current_style: style}), do: style

  @doc """
  Resets the style to default.
  """
  @spec reset_style(t()) :: t()
  def reset_style(buffer) do
    %{buffer | current_style: buffer.default_style}
  end

  @doc """
  Gets the style at a specific position (x, y).
  Returns the style at the position or the current style if not set.
  """
  @spec get_style_at(t(), non_neg_integer(), non_neg_integer()) :: style()
  def get_style_at(%__MODULE__{style_map: map, current_style: style}, x, y) do
    Map.get(map, {x, y}, style)
  end

  @doc """
  Applies a style to a rectangular region.
  """
  @spec apply_style_to_region(
          t(),
          style(),
          {non_neg_integer(), non_neg_integer()},
          {non_neg_integer(), non_neg_integer()}
        ) :: t()
  def apply_style_to_region(buffer, style, {x1, y1}, {x2, y2}) do
    coords = for x <- x1..x2, y <- y1..y2, do: {x, y}

    new_map =
      Enum.reduce(coords, buffer.style_map, fn pos, acc ->
        Map.put(acc, pos, style)
      end)

    %{buffer | style_map: new_map}
  end

  @doc """
  Sets the default style.
  """
  @spec set_default_style(t(), style()) :: t()
  def set_default_style(buffer, style) do
    %{buffer | default_style: style}
  end

  @doc """
  Gets the default style.
  """
  @spec get_default_style(t()) :: style()
  def get_default_style(%__MODULE__{default_style: style}), do: style

  @doc """
  Merges two styles.
  """
  @spec merge_styles(style(), style()) :: style()
  def merge_styles(style1, style2) do
    Map.merge(style1, style2)
  end

  @doc """
  Validates a style map.
  """
  @spec validate_style(style()) :: :ok | {:error, String.t()}
  def validate_style(style) when is_map(style) do
    # Basic validation - check for known style keys
    valid_keys = [
      :foreground,
      :background,
      :bold,
      :italic,
      :underline,
      :blink,
      :reverse,
      :hidden,
      :strikethrough
    ]

    invalid_keys = Map.keys(style) -- valid_keys

    validate_key_result(invalid_keys == [], invalid_keys)
  end

  def validate_style(_), do: {:error, "Style must be a map"}

  defp validate_key_result(true, _invalid_keys), do: :ok

  defp validate_key_result(false, invalid_keys),
    do: {:error, "Invalid style keys: #{inspect(invalid_keys)}"}
end
