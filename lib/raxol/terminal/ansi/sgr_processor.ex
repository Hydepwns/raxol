defmodule Raxol.Terminal.ANSI.SGRProcessor do
  @moduledoc """
  Handles SGR (Select Graphic Rendition) code processing.
  This module extracts the SGR processing logic from the main emulator.
  """

  @doc """
  Processes SGR parameters and applies them to the current style.
  """
  @spec handle_sgr(binary(), Raxol.Terminal.ANSI.TextFormatting.t()) :: Raxol.Terminal.ANSI.TextFormatting.t()
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

    log_sgr_debug("DEBUG: SGR codes parsed: #{inspect(codes)}")

    # Start with current style
    style = style || Raxol.Terminal.ANSI.TextFormatting.new()

    # Apply each SGR code, handling complex codes specially
    process_sgr_codes(codes, style)
  end

  @doc """
  Processes a list of SGR codes and applies them to the style.
  """
  @spec process_sgr_codes([integer()], Raxol.Terminal.ANSI.TextFormatting.t()) :: Raxol.Terminal.ANSI.TextFormatting.t()
  def process_sgr_codes([], style), do: style

  def process_sgr_codes([38, 5, color_index | rest], style) do
    # 8-bit foreground color: 38;5;n
    new_style = Raxol.Terminal.ANSI.TextFormatting.set_foreground(style, {:index, color_index})
    log_sgr_debug(
      "DEBUG: After applying 8-bit foreground color #{color_index}, style: #{inspect(new_style)}"
    )
    process_sgr_codes(rest, new_style)
  end

  def process_sgr_codes([48, 5, color_index | rest], style) do
    # 8-bit background color: 48;5;n
    new_style = Raxol.Terminal.ANSI.TextFormatting.set_background(style, {:index, color_index})
    log_sgr_debug(
      "DEBUG: After applying 8-bit background color #{color_index}, style: #{inspect(new_style)}"
    )
    process_sgr_codes(rest, new_style)
  end

  def process_sgr_codes([38, 2, r, g, b | rest], style) do
    # 24-bit foreground color: 38;2;r;g;b
    new_style = Raxol.Terminal.ANSI.TextFormatting.set_foreground(style, {:rgb, r, g, b})
    log_sgr_debug(
      "DEBUG: After applying 24-bit foreground color #{r},#{g},#{b}, style: #{inspect(new_style)}"
    )
    process_sgr_codes(rest, new_style)
  end

  def process_sgr_codes([48, 2, r, g, b | rest], style) do
    # 24-bit background color: 48;2;r;g;b
    new_style = Raxol.Terminal.ANSI.TextFormatting.set_background(style, {:rgb, r, g, b})
    log_sgr_debug(
      "DEBUG: After applying 24-bit background color #{r},#{g},#{b}, style: #{inspect(new_style)}"
    )
    process_sgr_codes(rest, new_style)
  end

  def process_sgr_codes([code | rest], style) do
    # Regular single-code processing
    case Map.fetch(sgr_code_mappings(), code) do
      {:ok, update_fn} ->
        result = update_fn.(style)
        log_sgr_debug(
          "DEBUG: apply_sgr_code #{code} => style: #{inspect(result)}"
        )
        process_sgr_codes(rest, result)

      :error ->
        # Unknown code, skip it
        log_sgr_debug("DEBUG: Unknown SGR code #{code}, skipping")
        process_sgr_codes(rest, style)
    end
  end

  @doc """
  Returns the mapping of SGR codes to their corresponding style update functions.
  """
  @spec sgr_code_mappings() :: map()
  def sgr_code_mappings do
    %{
      # Reset all attributes
      0 => fn _style -> Raxol.Terminal.ANSI.TextFormatting.new() end,

      # Intensity
      1 => &Raxol.Terminal.ANSI.TextFormatting.set_bold/1,
      2 => &Raxol.Terminal.ANSI.TextFormatting.set_faint/1,
      22 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.reset_bold()
        |> Raxol.Terminal.ANSI.TextFormatting.reset_faint()
      end,

      # Italic
      3 => &Raxol.Terminal.ANSI.TextFormatting.set_italic/1,
      23 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.reset_italic()
        |> Raxol.Terminal.ANSI.TextFormatting.reset_fraktur()
      end,

      # Underline
      4 => &Raxol.Terminal.ANSI.TextFormatting.set_underline/1,
      24 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.reset_underline()
        |> Raxol.Terminal.ANSI.TextFormatting.reset_double_underline()
      end,

      # Blink
      5 => &Raxol.Terminal.ANSI.TextFormatting.set_blink/1,
      6 => &Raxol.Terminal.ANSI.TextFormatting.set_blink/1,
      25 => &Raxol.Terminal.ANSI.TextFormatting.reset_blink/1,

      # Reverse
      7 => &Raxol.Terminal.ANSI.TextFormatting.set_reverse/1,
      27 => &Raxol.Terminal.ANSI.TextFormatting.reset_reverse/1,

      # Conceal
      8 => &Raxol.Terminal.ANSI.TextFormatting.set_conceal/1,
      28 => &Raxol.Terminal.ANSI.TextFormatting.reset_conceal/1,

      # Strikethrough
      9 => &Raxol.Terminal.ANSI.TextFormatting.set_strikethrough/1,
      29 => &Raxol.Terminal.ANSI.TextFormatting.reset_strikethrough/1,

      # Fraktur
      20 => &Raxol.Terminal.ANSI.TextFormatting.set_fraktur/1,

      # Double underline
      21 => &Raxol.Terminal.ANSI.TextFormatting.set_double_underline/1,

      # Foreground colors (30-37)
      30 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :black),
      31 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :red),
      32 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :green),
      33 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :yellow),
      34 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :blue),
      35 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :magenta),
      36 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :cyan),
      37 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, :white),
      39 => &Raxol.Terminal.ANSI.TextFormatting.set_foreground(&1, nil),

      # Background colors (40-47)
      40 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :black),
      41 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :red),
      42 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :green),
      43 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :yellow),
      44 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :blue),
      45 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :magenta),
      46 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :cyan),
      47 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :white),
      49 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, nil),

      # Bright foreground colors (90-97) - set bold and color
      90 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :black) end).()
      end,
      91 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :red) end).()
      end,
      92 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :green) end).()
      end,
      93 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :yellow) end).()
      end,
      94 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :blue) end).()
      end,
      95 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :magenta) end).()
      end,
      96 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :cyan) end).()
      end,
      97 => fn style ->
        style
        |> Raxol.Terminal.ANSI.TextFormatting.set_bold()
        |> (fn s -> Raxol.Terminal.ANSI.TextFormatting.set_foreground(s, :white) end).()
      end,

      # Bright background colors (100-107)
      100 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :black),
      101 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :red),
      102 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :green),
      103 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :yellow),
      104 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :blue),
      105 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :magenta),
      106 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :cyan),
      107 => &Raxol.Terminal.ANSI.TextFormatting.set_background(&1, :white),

      # Framed, encircled, overlined
      51 => &Raxol.Terminal.ANSI.TextFormatting.set_framed/1,
      52 => &Raxol.Terminal.ANSI.TextFormatting.set_encircled/1,
      53 => &Raxol.Terminal.ANSI.TextFormatting.set_overlined/1,
      54 => &Raxol.Terminal.ANSI.TextFormatting.reset_framed_encircled/1,
      55 => &Raxol.Terminal.ANSI.TextFormatting.reset_overlined/1
    }
  end

  # Private functions

  defp log_sgr_debug(msg) do
    File.write!("tmp/sgr_debug.log", msg <> "\n", [:append])
  end
end
