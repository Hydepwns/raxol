defmodule Raxol.Terminal.Font.Manager do
  @moduledoc """
  Manages font operations and settings for the terminal, including font family,
  size, weight, and style.
  """

  defstruct [
    :family,
    :size,
    :weight,
    :style,
    :line_height,
    :letter_spacing,
    :fallback_fonts,
    :custom_fonts
  ]

  @type font_family :: String.t()
  @type font_size :: non_neg_integer()
  @type font_weight :: :normal | :bold | :lighter | :bolder | 100..900
  @type font_style :: :normal | :italic | :oblique
  @type line_height :: number()
  @type letter_spacing :: number()
  @type fallback_fonts :: [font_family()]
  @type custom_fonts :: %{String.t() => String.t()}

  @type t :: %__MODULE__{
          family: font_family(),
          size: font_size(),
          weight: font_weight(),
          style: font_style(),
          line_height: line_height(),
          letter_spacing: letter_spacing(),
          fallback_fonts: fallback_fonts(),
          custom_fonts: custom_fonts()
        }

  @doc """
  Creates a new font manager instance with default settings.
  """
  def new do
    %__MODULE__{
      family: "monospace",
      size: 14,
      weight: :normal,
      style: :normal,
      line_height: 1.2,
      letter_spacing: 0,
      fallback_fonts: ["monospace"],
      custom_fonts: %{}
    }
  end

  @doc """
  Sets the font family.
  """
  def set_family(%__MODULE__{} = manager, family) when is_binary(family) do
    %{manager | family: family}
  end

  @doc """
  Gets the current font family.
  """
  def get_family(%__MODULE__{} = manager) do
    manager.family
  end

  @doc """
  Sets the font size.
  """
  def set_size(%__MODULE__{} = manager, size)
      when is_integer(size) and size > 0 do
    %{manager | size: size}
  end

  @doc """
  Gets the current font size.
  """
  def get_size(%__MODULE__{} = manager) do
    manager.size
  end

  @doc """
  Sets the font weight.
  """
  def set_weight(%__MODULE__{} = manager, weight)
      when weight in [:normal, :bold, :lighter, :bolder] or
             (is_integer(weight) and weight in 100..900) do
    %{manager | weight: weight}
  end

  @doc """
  Gets the current font weight.
  """
  def get_weight(%__MODULE__{} = manager) do
    manager.weight
  end

  @doc """
  Sets the font style.
  """
  def set_style(%__MODULE__{} = manager, style)
      when style in [:normal, :italic, :oblique] do
    %{manager | style: style}
  end

  @doc """
  Gets the current font style.
  """
  def get_style(%__MODULE__{} = manager) do
    manager.style
  end

  @doc """
  Sets the line height.
  """
  def set_line_height(%__MODULE__{} = manager, height)
      when is_number(height) and height > 0 do
    %{manager | line_height: height}
  end

  @doc """
  Gets the current line height.
  """
  def get_line_height(%__MODULE__{} = manager) do
    manager.line_height
  end

  @doc """
  Sets the letter spacing.
  """
  def set_letter_spacing(%__MODULE__{} = manager, spacing)
      when is_number(spacing) do
    %{manager | letter_spacing: spacing}
  end

  @doc """
  Gets the current letter spacing.
  """
  def get_letter_spacing(%__MODULE__{} = manager) do
    manager.letter_spacing
  end

  @doc """
  Sets the fallback fonts.
  """
  def set_fallback_fonts(%__MODULE__{} = manager, fonts) when is_list(fonts) do
    %{manager | fallback_fonts: fonts}
  end

  @doc """
  Gets the current fallback fonts.
  """
  def get_fallback_fonts(%__MODULE__{} = manager) do
    manager.fallback_fonts
  end

  @doc """
  Adds a custom font.
  """
  def add_custom_font(%__MODULE__{} = manager, name, path)
      when is_binary(name) and is_binary(path) do
    custom_fonts = Map.put(manager.custom_fonts, name, path)
    %{manager | custom_fonts: custom_fonts}
  end

  @doc """
  Removes a custom font.
  """
  def remove_custom_font(%__MODULE__{} = manager, name) when is_binary(name) do
    custom_fonts = Map.delete(manager.custom_fonts, name)
    %{manager | custom_fonts: custom_fonts}
  end

  @doc """
  Gets the current custom fonts.
  """
  def get_custom_fonts(%__MODULE__{} = manager) do
    manager.custom_fonts
  end

  @doc """
  Gets the complete font stack including fallbacks.
  """
  def get_font_stack(%__MODULE__{} = manager) do
    [manager.family | manager.fallback_fonts]
  end

  @doc """
  Resets the font manager to its initial state.
  """
  def reset(%__MODULE__{} = manager) do
    new()
  end
end
