defmodule Raxol.Core.Renderer.View.Utils.ViewUtils do
  @moduledoc """
  Provides utility functions for common view operations in the Raxol view system.
  """

  @doc """
  Normalizes spacing values for padding and margin.
  Accepts various input formats and converts them to a standardized format.

  ## Examples

      normalize_spacing(5)           # {5, 5, 5, 5}
      normalize_spacing({10, 20})    # {10, 20, 10, 20}
      normalize_spacing({1, 2, 3, 4}) # {1, 2, 3, 4}
  """
  def normalize_spacing(spacing) when is_integer(spacing) do
    if spacing < 0 do
      raise ArgumentError, "Padding must be a positive integer or tuple"
    end

    {spacing, spacing, spacing, spacing}
  end

  def normalize_spacing({top, right, bottom, left}) do
    if not (is_integer(top) and is_integer(right) and is_integer(bottom) and
              is_integer(left)) or
         top < 0 or right < 0 or bottom < 0 or left < 0 do
      raise ArgumentError, "Padding must be a positive integer or tuple"
    end

    {top, right, bottom, left}
  end

  def normalize_spacing({vertical, horizontal}) do
    if not (is_integer(vertical) and is_integer(horizontal)) or
         vertical < 0 or horizontal < 0 do
      raise ArgumentError, "Padding must be a positive integer or tuple"
    end

    {vertical, horizontal, vertical, horizontal}
  end

  def normalize_spacing(invalid) do
    if is_integer(invalid) and invalid < 0 do
      raise ArgumentError, "Padding must be a positive integer or tuple"
    end

    if is_tuple(invalid) and tuple_size(invalid) == 3 do
      raise ArgumentError, "Invalid padding tuple length"
    end

    raise ArgumentError, "Padding must be a positive integer or tuple"
  end

  @doc """
  Normalizes margin values for padding and margin.
  Accepts various input formats and converts them to a standardized format.

  ## Examples

      normalize_margin(5)           # {5, 5, 5, 5}
      normalize_margin({10, 20})    # {10, 20, 10, 20}
      normalize_margin({1, 2, 3, 4}) # {1, 2, 3, 4}
  """
  def normalize_margin(spacing) when is_integer(spacing) do
    if spacing < 0 do
      raise ArgumentError, "Margin must be a positive integer or tuple"
    end

    {spacing, spacing, spacing, spacing}
  end

  def normalize_margin({top, right, bottom, left}) do
    if not (is_integer(top) and is_integer(right) and is_integer(bottom) and
              is_integer(left)) or
         top < 0 or right < 0 or bottom < 0 or left < 0 do
      raise ArgumentError, "Margin must be a positive integer or tuple"
    end

    {top, right, bottom, left}
  end

  def normalize_margin({vertical, horizontal}) do
    if not (is_integer(vertical) and is_integer(horizontal)) or
         vertical < 0 or horizontal < 0 do
      raise ArgumentError, "Margin must be a positive integer or tuple"
    end

    {vertical, horizontal, vertical, horizontal}
  end

  def normalize_margin(invalid) do
    if is_integer(invalid) and invalid < 0 do
      raise ArgumentError, "Margin must be a positive integer or tuple"
    end

    if is_tuple(invalid) and tuple_size(invalid) == 3 do
      raise ArgumentError, "Invalid margin tuple length"
    end

    raise ArgumentError, "Margin must be a positive integer or tuple"
  end

  @doc """
  Applies styles to a string of text.

  ## Options
    * `:bold` - Makes text bold
    * `:underline` - Underlines text
    * `:italic` - Makes text italic
    * `:strikethrough` - Adds strikethrough to text
  """
  def apply_styles(text, styles) do
    Enum.reduce(styles, text, fn
      {:bold, true}, acc -> "\e[1m#{acc}\e[22m"
      {:underline, true}, acc -> "\e[4m#{acc}\e[24m"
      {:italic, true}, acc -> "\e[3m#{acc}\e[23m"
      {:strikethrough, true}, acc -> "\e[9m#{acc}\e[29m"
      _, acc -> acc
    end)
  end

  @doc """
  Applies foreground and background colors to text.

  ## Examples

      apply_colors("Hello", fg: :red, bg: :blue)
      apply_colors("World", fg: {255, 0, 0}, bg: {0, 0, 255})
  """
  def apply_colors(text, fg: fg, bg: bg) do
    text
    |> apply_foreground(fg)
    |> apply_background(bg)
  end

  defp apply_foreground(text, nil), do: text

  defp apply_foreground(text, color) when is_atom(color) do
    code = color_to_code(color)
    "\e[38;5;#{code}m#{text}\e[39m"
  end

  defp apply_foreground(text, {r, g, b}) do
    "\e[38;2;#{r};#{g};#{b}m#{text}\e[39m"
  end

  defp apply_background(text, nil), do: text

  defp apply_background(text, color) when is_atom(color) do
    code = color_to_code(color)
    "\e[48;5;#{code}m#{text}\e[49m"
  end

  defp apply_background(text, {r, g, b}) do
    "\e[48;2;#{r};#{g};#{b}m#{text}\e[49m"
  end

  @doc """
  Converts a color name to its ANSI color code.
  """
  def color_to_code(color) do
    color_codes = %{
      black: 0,
      red: 1,
      green: 2,
      yellow: 3,
      blue: 4,
      magenta: 5,
      cyan: 6,
      white: 7,
      bright_black: 8,
      bright_red: 9,
      bright_green: 10,
      bright_yellow: 11,
      bright_blue: 12,
      bright_magenta: 13,
      bright_cyan: 14,
      bright_white: 15
    }

    # Default to white
    Map.get(color_codes, color, 7)
  end

  @doc """
  Calculates the dimensions of a view based on its content and constraints.
  """
  def calculate_dimensions(view, available_size) do
    {min_width, min_height} = get_minimum_size(view)
    {max_width, max_height} = get_maximum_size(view)
    {available_width, available_height} = available_size

    width = calculate_dimension(min_width, max_width, available_width)
    height = calculate_dimension(min_height, max_height, available_height)

    {width, height}
  end

  defp get_minimum_size(_view) do
    # Calculate minimum size based on content and constraints
    {0, 0}
  end

  defp get_maximum_size(_view) do
    # Calculate maximum size based on content and constraints
    {nil, nil}
  end

  defp calculate_dimension(min, max, available) do
    case {min, max, available} do
      {min, _max, available} when not is_nil(min) and available < min -> min
      {_min, max, available} when not is_nil(max) and available > max -> max
      {_min, _max, available} -> available
    end
  end

  @doc """
  Merges two views, with the second view's properties taking precedence.
  """
  def merge_views(base_view, override_view) do
    Map.merge(base_view, override_view, fn
      :children, base_children, override_children ->
        base_children ++ override_children

      _key, _base_value, override_value ->
        override_value
    end)
  end
end
