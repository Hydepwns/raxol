defmodule Raxol.Terminal.ANSI.TextFormatting.SGR do
  @moduledoc """
  SGR parameter formatting and parsing for text styles.
  """
  @compile {:no_warn_undefined,
            [
              Raxol.Terminal.ANSI.TextFormatting.ColorMap,
              Raxol.Terminal.ANSI.TextFormatting.Colors
            ]}

  alias Raxol.Terminal.ANSI.TextFormatting.{ColorMap, Colors}

  @sgr_attribute_setters %{
    1 => :bold,
    2 => :faint,
    3 => :italic,
    4 => :underline,
    5 => :blink,
    6 => :blink,
    7 => :reverse,
    8 => :conceal,
    9 => :strikethrough,
    20 => :fraktur,
    21 => :double_underline,
    51 => :framed,
    52 => :encircled,
    53 => :overlined
  }

  @sgr_attribute_resetters %{
    22 => [:bold, :faint],
    23 => [:italic, :fraktur],
    24 => [:underline, :double_underline],
    25 => [:blink],
    27 => [:reverse],
    28 => [:conceal],
    29 => [:strikethrough],
    54 => [:framed, :encircled],
    55 => [:overlined]
  }

  def format_sgr_params(style) do
    codes = []
    codes = if style.bold, do: ["1" | codes], else: codes
    codes = if style.italic, do: ["3" | codes], else: codes
    codes = if style.underline, do: ["4" | codes], else: codes
    codes = if style.blink, do: ["5" | codes], else: codes
    codes = if style.reverse, do: ["7" | codes], else: codes
    codes = if style.conceal, do: ["8" | codes], else: codes
    codes = if style.strikethrough, do: ["9" | codes], else: codes

    codes = codes ++ Colors.build_foreground_codes(style.foreground)
    codes = codes ++ Colors.build_background_codes(style.background)

    codes
    |> Enum.reverse()
    |> Enum.join(";")
  end

  def parse_sgr_param(param, style) do
    cond do
      param == 0 ->
        Raxol.Terminal.ANSI.TextFormatting.Core.new()

      attr = @sgr_attribute_setters[param] ->
        %{style | attr => true}

      fields = @sgr_attribute_resetters[param] ->
        Enum.reduce(fields, style, fn field, acc -> %{acc | field => false} end)

      color = ColorMap.sgr_fg_color(param) ->
        %{style | foreground: color}

      param == 39 ->
        %{style | foreground: nil}

      color = ColorMap.sgr_bg_color(param) ->
        %{style | background: color}

      param == 49 ->
        %{style | background: nil}

      color = ColorMap.sgr_bright_fg(param) ->
        %{style | foreground: color, bold: true}

      color = ColorMap.sgr_bright_bg(param) ->
        %{style | background: color}

      true ->
        parse_extended_sgr(param, style)
    end
  end

  defp parse_extended_sgr(param, style) do
    case param do
      {:fg_8bit, n} when is_integer(n) and n >= 0 and n <= 255 ->
        %{style | foreground: {:index, n}}

      {:bg_8bit, n} when is_integer(n) and n >= 0 and n <= 255 ->
        %{style | background: {:index, n}}

      {:fg_rgb, r, g, b} ->
        %{style | foreground: {:rgb, r, g, b}}

      {:bg_rgb, r, g, b} ->
        %{style | background: {:rgb, r, g, b}}

      _ ->
        style
    end
  end
end
