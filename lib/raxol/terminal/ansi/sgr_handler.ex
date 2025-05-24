defmodule Raxol.Terminal.ANSI.SGRHandler do
  @moduledoc """
  Handles parsing of SGR (Select Graphic Rendition) ANSI escape sequences.
  Translates SGR codes into updates on a TextFormatting style map.
  """

  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Applies a list of SGR parameters to the current style.
  Handles multi-parameter sequences like 38/48.
  """
  @spec apply_sgr_params(list(integer() | tuple()), TextFormatting.text_style()) ::
          TextFormatting.text_style()
  def apply_sgr_params(params, current_style) do
    do_apply_sgr_params(params, current_style)
  end

  # Base case: no more parameters
  defp do_apply_sgr_params([], style), do: style

  # Handle 38/48 ; 5 ; <index> (8-bit color)
  defp do_apply_sgr_params([38, 5, index | rest], style)
       when is_integer(index) do
    new_style = TextFormatting.apply_color(style, :foreground, {:index, index})
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([48, 5, index | rest], style)
       when is_integer(index) do
    new_style = TextFormatting.apply_color(style, :background, {:index, index})
    do_apply_sgr_params(rest, new_style)
  end

  # Handle 38/48 ; 2 ; <r> ; <g> ; <b> (24-bit color)
  defp do_apply_sgr_params([38, 2, r, g, b | rest], style)
       when is_integer(r) and is_integer(g) and is_integer(b) do
    new_style = TextFormatting.apply_color(style, :foreground, {:rgb, r, g, b})
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([48, 2, r, g, b | rest], style)
       when is_integer(r) and is_integer(g) and is_integer(b) do
    new_style = TextFormatting.apply_color(style, :background, {:rgb, r, g, b})
    do_apply_sgr_params(rest, new_style)
  end

  # Handle single parameter
  defp do_apply_sgr_params([param | rest], style) when is_integer(param) do
    new_style = parse_single_sgr_param(param, style)
    do_apply_sgr_params(rest, new_style)
  end

  # Skip invalid parameters (e.g., leftover from 38/48 parsing if sequence was short)
  defp do_apply_sgr_params([_ | rest], style) do
    do_apply_sgr_params(rest, style)
  end

  @doc false
  # Parses a single integer SGR parameter
  defp parse_single_sgr_param(param, %{} = current_style) do
    case param do
      # Reset all attributes
      0 ->
        TextFormatting.new()

      1 ->
        TextFormatting.apply_attribute(current_style, :bold)

      2 ->
        TextFormatting.apply_attribute(current_style, :faint)

      3 ->
        TextFormatting.apply_attribute(current_style, :italic)

      4 ->
        TextFormatting.apply_attribute(current_style, :underline)

      5 ->
        TextFormatting.apply_attribute(current_style, :blink)

      # Add Fast Blink (treat as slow)
      6 ->
        TextFormatting.apply_attribute(current_style, :blink)

      7 ->
        TextFormatting.apply_attribute(current_style, :reverse)

      8 ->
        TextFormatting.apply_attribute(current_style, :conceal)

      9 ->
        TextFormatting.apply_attribute(current_style, :strikethrough)

      20 ->
        TextFormatting.apply_attribute(current_style, :fraktur)

      21 ->
        TextFormatting.apply_attribute(current_style, :double_underline)

      22 ->
        TextFormatting.apply_attribute(current_style, :normal_intensity)

      23 ->
        TextFormatting.apply_attribute(current_style, :no_italic_fraktur)

      24 ->
        TextFormatting.apply_attribute(current_style, :no_underline)

      25 ->
        TextFormatting.apply_attribute(current_style, :no_blink)

      27 ->
        TextFormatting.apply_attribute(current_style, :no_reverse)

      28 ->
        TextFormatting.apply_attribute(current_style, :reveal)

      29 ->
        TextFormatting.apply_attribute(current_style, :no_strikethrough)

      30 ->
        TextFormatting.apply_attribute(current_style, :black)

      31 ->
        TextFormatting.apply_attribute(current_style, :red)

      32 ->
        TextFormatting.apply_attribute(current_style, :green)

      33 ->
        TextFormatting.apply_attribute(current_style, :yellow)

      34 ->
        TextFormatting.apply_attribute(current_style, :blue)

      35 ->
        TextFormatting.apply_attribute(current_style, :magenta)

      36 ->
        TextFormatting.apply_attribute(current_style, :cyan)

      37 ->
        TextFormatting.apply_attribute(current_style, :white)

      # SGR 38: Set foreground color (handled by do_apply_sgr_params)
      38 ->
        TextFormatting.apply_attribute(current_style, :default_fg)

      # SGR 39: Default foreground color
      39 ->
        TextFormatting.apply_attribute(current_style, :default_fg)

      40 ->
        TextFormatting.apply_attribute(current_style, :bg_black)

      41 ->
        TextFormatting.apply_attribute(current_style, :bg_red)

      42 ->
        TextFormatting.apply_attribute(current_style, :bg_green)

      43 ->
        TextFormatting.apply_attribute(current_style, :bg_yellow)

      44 ->
        TextFormatting.apply_attribute(current_style, :bg_blue)

      45 ->
        TextFormatting.apply_attribute(current_style, :bg_magenta)

      46 ->
        TextFormatting.apply_attribute(current_style, :bg_cyan)

      47 ->
        TextFormatting.apply_attribute(current_style, :bg_white)

      # SGR 48: Set background color (handled by do_apply_sgr_params)
      48 ->
        TextFormatting.apply_attribute(current_style, :default_bg)

      # SGR 49: Default background color
      49 ->
        TextFormatting.apply_attribute(current_style, :default_bg)

      # SGR 51-55: Framed, Encircled, Overlined, Not Framed/Encircled, Not Overlined
      51 ->
        TextFormatting.apply_attribute(current_style, :framed)

      52 ->
        TextFormatting.apply_attribute(current_style, :encircled)

      53 ->
        TextFormatting.apply_attribute(current_style, :overlined)

      54 ->
        TextFormatting.apply_attribute(current_style, :not_framed_encircled)

      55 ->
        TextFormatting.apply_attribute(current_style, :not_overlined)

      # TODO: Add codes 51-55 (framed, encircled, overlined, etc.) if needed
      # Bright Foreground Colors (90-97) - Implies Bold
      param when param >= 90 and param <= 97 ->
        color_attr = index_to_basic_color_attr(param - 90)

        TextFormatting.apply_attribute(current_style, color_attr)
        |> TextFormatting.apply_attribute(:bold)

      # Bright Background Colors (100-107)
      param when param >= 100 and param <= 107 ->
        color_attr = index_to_basic_bg_color_attr(param - 100)
        TextFormatting.apply_attribute(current_style, color_attr)

      # Ignore unknown/unsupported codes
      _ ->
        current_style
    end
  end

  # Helper to map basic color indices (0-7) to foreground attribute atoms
  defp index_to_basic_color_attr(index) do
    [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]
    |> Enum.at(index)
  end

  # Helper to map basic color indices (0-7) to background attribute atoms
  defp index_to_basic_bg_color_attr(index) do
    [
      :bg_black,
      :bg_red,
      :bg_green,
      :bg_yellow,
      :bg_blue,
      :bg_magenta,
      :bg_cyan,
      :bg_white
    ]
    |> Enum.at(index)
  end
end
