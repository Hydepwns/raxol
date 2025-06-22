defmodule Raxol.Terminal.ANSI.SGRHandler do
  @moduledoc """
  Handles parsing of SGR (Select Graphic Rendition) ANSI escape sequences.
  Translates SGR codes into updates on a TextFormatting style map.
  """

  import Raxol.Guards

  alias Raxol.Terminal.ANSI.TextFormatting

  @text_style_map %{
    20 => :fraktur,
    21 => :double_underline,
    22 => :normal_intensity,
    23 => :no_italic_fraktur,
    24 => :no_underline,
    25 => :no_blink,
    27 => :no_reverse,
    28 => :reveal,
    29 => :no_strikethrough
  }

  @fg_color_map %{
    30 => :black,
    31 => :red,
    32 => :green,
    33 => :yellow,
    34 => :blue,
    35 => :magenta,
    36 => :cyan,
    37 => :white,
    38 => :default_fg,
    39 => :default_fg
  }

  @bg_color_map %{
    40 => :bg_black,
    41 => :bg_red,
    42 => :bg_green,
    43 => :bg_yellow,
    44 => :bg_blue,
    45 => :bg_magenta,
    46 => :bg_cyan,
    47 => :bg_white,
    48 => :default_bg,
    49 => :default_bg
  }

  @doc """
  Applies a list of SGR parameters to the current style.
  Handles multi-parameter sequences like 38/48.
  """
  @spec apply_sgr_params(list(integer() | tuple()), TextFormatting.text_style()) ::
          TextFormatting.text_style()
  def apply_sgr_params(params, current_style) do
    new_style = do_apply_sgr_params(params, current_style)
    require Raxol.Core.Runtime.Log

    Raxol.Core.Runtime.Log.debug(
      "[SGRHandler] Applied SGR params #{inspect(params)}; new style: #{inspect(new_style)}"
    )

    new_style
  end

  defp do_apply_sgr_params([], style), do: style

  defp do_apply_sgr_params([38, 5, index | rest], style)
       when integer?(index) do
    new_style = TextFormatting.apply_color(style, :foreground, {:index, index})
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([48, 5, index | rest], style)
       when integer?(index) do
    new_style = TextFormatting.apply_color(style, :background, {:index, index})
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([38, 2, r, g, b | rest], style)
       when integer?(r) and integer?(g) and integer?(b) do
    new_style = TextFormatting.apply_color(style, :foreground, {:rgb, r, g, b})
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([48, 2, r, g, b | rest], style)
       when integer?(r) and integer?(g) and integer?(b) do
    new_style = TextFormatting.apply_color(style, :background, {:rgb, r, g, b})
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([param | rest], style) when integer?(param) do
    new_style = parse_single_sgr_param(param, style)
    do_apply_sgr_params(rest, new_style)
  end

  defp do_apply_sgr_params([_ | rest], style) do
    do_apply_sgr_params(rest, style)
  end

  @doc false
  # Parses a single integer SGR parameter
  defp parse_single_sgr_param(param, current_style) do
    case param do
      0 -> TextFormatting.new()
      _ -> handle_param_range(param, current_style)
    end
  end

  @param_range_handlers %{
    (1..9) => &__MODULE__.handle_basic_attributes/2,
    (20..29) => &__MODULE__.handle_text_style_attributes/2,
    (30..39) => &__MODULE__.handle_foreground_colors/2,
    (40..49) => &__MODULE__.handle_background_colors/2,
    (51..55) => &__MODULE__.handle_decoration_attributes/2,
    (90..97) => &__MODULE__.handle_bright_foreground_colors/2,
    (100..107) => &__MODULE__.handle_bright_background_colors/2
  }

  defp handle_param_range(param, style) do
    Enum.find_value(@param_range_handlers, style, fn {range, handler} ->
      if param in range, do: handler.(param, style)
    end)
  end

  @basic_attributes_map %{
    1 => :bold,
    2 => :faint,
    3 => :italic,
    4 => :underline,
    5 => :blink,
    6 => :blink,
    7 => :reverse,
    8 => :conceal,
    9 => :strikethrough
  }

  defp handle_basic_attributes(param, style) do
    case Map.get(@basic_attributes_map, param) do
      nil -> style
      attr -> TextFormatting.apply_attribute(style, attr)
    end
  end

  defp handle_text_style_attributes(param, style) do
    case Map.get(@text_style_map, param) do
      nil -> style
      attr -> TextFormatting.apply_attribute(style, attr)
    end
  end

  defp handle_foreground_colors(param, style) do
    case Map.get(@fg_color_map, param) do
      nil -> style
      attr -> TextFormatting.apply_attribute(style, attr)
    end
  end

  defp handle_background_colors(param, style) do
    case Map.get(@bg_color_map, param) do
      nil -> style
      attr -> TextFormatting.apply_attribute(style, attr)
    end
  end

  @decoration_attributes_map %{
    51 => :framed,
    52 => :encircled,
    53 => :overlined,
    54 => :not_framed_encircled,
    55 => :not_overlined
  }

  defp handle_decoration_attributes(param, style) do
    case Map.get(@decoration_attributes_map, param) do
      nil -> style
      attr -> TextFormatting.apply_attribute(style, attr)
    end
  end

  defp handle_bright_foreground(param, style) do
    color_attr = index_to_basic_color_attr(param - 90)

    TextFormatting.apply_attribute(style, color_attr)
    |> TextFormatting.apply_attribute(:bold)
  end

  defp handle_bright_background(param, style) do
    color_attr = index_to_basic_bg_color_attr(param - 100)
    TextFormatting.apply_attribute(style, color_attr)
  end

  defp index_to_basic_color_attr(index) do
    [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]
    |> Enum.at(index)
  end

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
