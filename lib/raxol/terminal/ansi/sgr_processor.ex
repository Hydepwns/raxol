defmodule Raxol.Terminal.ANSI.SGRProcessor do
  @moduledoc """
  Optimized SGR (Select Graphic Rendition) processor for ANSI escape sequences.

  This version uses compile-time optimizations and pattern matching for
  maximum performance.
  """

  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Processes SGR parameters and applies them to the current style.
  """
  @spec handle_sgr(binary(), TextFormatting.t()) :: TextFormatting.t()
  def handle_sgr(params, style) do
    # Parse SGR parameters (e.g., "31;1;4")
    codes =
      params
      |> String.split(";")
      |> Enum.map(fn code ->
        case Integer.parse(code) do
          {int, _} -> int
          :error -> nil
        end
      end)
      |> Enum.filter(& &1)

    # Start with current style
    style = style || TextFormatting.new()

    # Apply each SGR code
    process_sgr_codes(codes, style)
  end

  # Direct pattern matching for common SGR codes - much faster than map lookup
  def process_sgr_codes([], style), do: style

  # Reset all - most common operation
  def process_sgr_codes([0 | rest], _style) do
    process_sgr_codes(rest, TextFormatting.new())
  end

  # Foreground colors (30-37, 90-97)
  def process_sgr_codes([30 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :black})
  end

  def process_sgr_codes([31 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :red})
  end

  def process_sgr_codes([32 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :green})
  end

  def process_sgr_codes([33 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :yellow})
  end

  def process_sgr_codes([34 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :blue})
  end

  def process_sgr_codes([35 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :magenta})
  end

  def process_sgr_codes([36 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :cyan})
  end

  def process_sgr_codes([37 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :white})
  end

  # Default foreground
  def process_sgr_codes([39 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: nil})
  end

  # Background colors (40-47, 100-107)
  def process_sgr_codes([40 | rest], style) do
    process_sgr_codes(rest, %{style | background: :black})
  end

  def process_sgr_codes([41 | rest], style) do
    process_sgr_codes(rest, %{style | background: :red})
  end

  def process_sgr_codes([42 | rest], style) do
    process_sgr_codes(rest, %{style | background: :green})
  end

  def process_sgr_codes([43 | rest], style) do
    process_sgr_codes(rest, %{style | background: :yellow})
  end

  def process_sgr_codes([44 | rest], style) do
    process_sgr_codes(rest, %{style | background: :blue})
  end

  def process_sgr_codes([45 | rest], style) do
    process_sgr_codes(rest, %{style | background: :magenta})
  end

  def process_sgr_codes([46 | rest], style) do
    process_sgr_codes(rest, %{style | background: :cyan})
  end

  def process_sgr_codes([47 | rest], style) do
    process_sgr_codes(rest, %{style | background: :white})
  end

  # Default background
  def process_sgr_codes([49 | rest], style) do
    process_sgr_codes(rest, %{style | background: nil})
  end

  # Bright foreground colors (90-97) - set base color + bold for compatibility
  def process_sgr_codes([90 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :black, bold: true})
  end

  def process_sgr_codes([91 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :red, bold: true})
  end

  def process_sgr_codes([92 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :green, bold: true})
  end

  def process_sgr_codes([93 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :yellow, bold: true})
  end

  def process_sgr_codes([94 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :blue, bold: true})
  end

  def process_sgr_codes([95 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :magenta, bold: true})
  end

  def process_sgr_codes([96 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :cyan, bold: true})
  end

  def process_sgr_codes([97 | rest], style) do
    process_sgr_codes(rest, %{style | foreground: :white, bold: true})
  end

  # Bright background colors (100-107) - just base colors, no bold
  def process_sgr_codes([100 | rest], style) do
    process_sgr_codes(rest, %{style | background: :black})
  end

  def process_sgr_codes([101 | rest], style) do
    process_sgr_codes(rest, %{style | background: :red})
  end

  def process_sgr_codes([102 | rest], style) do
    process_sgr_codes(rest, %{style | background: :green})
  end

  def process_sgr_codes([103 | rest], style) do
    process_sgr_codes(rest, %{style | background: :yellow})
  end

  def process_sgr_codes([104 | rest], style) do
    process_sgr_codes(rest, %{style | background: :blue})
  end

  def process_sgr_codes([105 | rest], style) do
    process_sgr_codes(rest, %{style | background: :magenta})
  end

  def process_sgr_codes([106 | rest], style) do
    process_sgr_codes(rest, %{style | background: :cyan})
  end

  def process_sgr_codes([107 | rest], style) do
    process_sgr_codes(rest, %{style | background: :white})
  end

  # Text attributes
  def process_sgr_codes([1 | rest], style) do
    process_sgr_codes(rest, %{style | bold: true})
  end

  def process_sgr_codes([2 | rest], style) do
    process_sgr_codes(rest, %{style | faint: true})
  end

  def process_sgr_codes([3 | rest], style) do
    process_sgr_codes(rest, %{style | italic: true})
  end

  def process_sgr_codes([4 | rest], style) do
    process_sgr_codes(rest, %{style | underline: true})
  end

  def process_sgr_codes([5 | rest], style) do
    process_sgr_codes(rest, %{style | blink: true})
  end

  def process_sgr_codes([6 | rest], style) do
    # Rapid blink
    process_sgr_codes(rest, %{style | blink: true})
  end

  def process_sgr_codes([7 | rest], style) do
    process_sgr_codes(rest, %{style | reverse: true})
  end

  def process_sgr_codes([8 | rest], style) do
    process_sgr_codes(rest, %{style | conceal: true})
  end

  def process_sgr_codes([9 | rest], style) do
    process_sgr_codes(rest, %{style | strikethrough: true})
  end

  # Additional text attributes
  def process_sgr_codes([20 | rest], style) do
    process_sgr_codes(rest, %{style | fraktur: true})
  end

  def process_sgr_codes([21 | rest], style) do
    process_sgr_codes(rest, %{style | double_underline: true})
  end

  # Reset attributes
  def process_sgr_codes([22 | rest], style) do
    process_sgr_codes(rest, %{style | bold: false, faint: false})
  end

  def process_sgr_codes([23 | rest], style) do
    process_sgr_codes(rest, %{style | italic: false, fraktur: false})
  end

  def process_sgr_codes([24 | rest], style) do
    process_sgr_codes(rest, %{style | underline: false, double_underline: false})
  end

  def process_sgr_codes([25 | rest], style) do
    process_sgr_codes(rest, %{style | blink: false})
  end

  def process_sgr_codes([27 | rest], style) do
    process_sgr_codes(rest, %{style | reverse: false})
  end

  def process_sgr_codes([28 | rest], style) do
    process_sgr_codes(rest, %{style | conceal: false})
  end

  def process_sgr_codes([29 | rest], style) do
    process_sgr_codes(rest, %{style | strikethrough: false})
  end

  # Framed, encircled, overlined
  def process_sgr_codes([51 | rest], style) do
    process_sgr_codes(rest, %{style | framed: true})
  end

  def process_sgr_codes([52 | rest], style) do
    process_sgr_codes(rest, %{style | encircled: true})
  end

  def process_sgr_codes([53 | rest], style) do
    process_sgr_codes(rest, %{style | overlined: true})
  end

  def process_sgr_codes([54 | rest], style) do
    process_sgr_codes(rest, %{style | framed: false, encircled: false})
  end

  def process_sgr_codes([55 | rest], style) do
    process_sgr_codes(rest, %{style | overlined: false})
  end

  # 256-color support (38;5;n for foreground, 48;5;n for background)
  def process_sgr_codes([38, 5, color | rest], style) do
    process_sgr_codes(
      rest,
      TextFormatting.set_foreground(style, {:index, color})
    )
  end

  def process_sgr_codes([48, 5, color | rest], style) do
    process_sgr_codes(
      rest,
      TextFormatting.set_background(style, {:index, color})
    )
  end

  # RGB color support (38;2;r;g;b for foreground, 48;2;r;g;b for background)
  def process_sgr_codes([38, 2, r, g, b | rest], style) do
    process_sgr_codes(
      rest,
      TextFormatting.set_foreground(style, {:rgb, r, g, b})
    )
  end

  def process_sgr_codes([48, 2, r, g, b | rest], style) do
    process_sgr_codes(
      rest,
      TextFormatting.set_background(style, {:rgb, r, g, b})
    )
  end

  # Unknown codes - skip them
  def process_sgr_codes([_unknown | rest], style) do
    process_sgr_codes(rest, style)
  end

  @doc """
  Returns the mapping of SGR codes to their corresponding style update functions.
  Kept for backward compatibility but not used in optimized path.
  """
  @spec sgr_code_mappings() :: map()
  def sgr_code_mappings do
    # This function is kept for backward compatibility
    # but the optimized version uses pattern matching instead
    %{}
  end
end
