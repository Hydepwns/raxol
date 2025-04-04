defmodule Raxol.Terminal.ANSI do
  @moduledoc """
  ANSI escape code processing module.
  
  This module handles the parsing and processing of ANSI escape codes,
  including:
  - Cursor movement and positioning
  - Color and style attributes (16, 256, and true color)
  - Screen clearing and manipulation
  - Terminal mode switching
  - Line editing
  - Scrolling region
  - Character sets
  """

  # Standard 16 colors
  @colors %{
    0 => :black,
    1 => :red,
    2 => :green,
    3 => :yellow,
    4 => :blue,
    5 => :magenta,
    6 => :cyan,
    7 => :white,
    8 => :bright_black,
    9 => :bright_red,
    10 => :bright_green,
    11 => :bright_yellow,
    12 => :bright_blue,
    13 => :bright_magenta,
    14 => :bright_cyan,
    15 => :bright_white
  }

  # 256-color mode palette
  # 0-15: Standard colors (same as @colors)
  # 16-231: 6x6x6 RGB cube
  # 232-255: Grayscale
  @color_256_palette %{
    # RGB cube (16-231)
    16..231 => fn code ->
      code = code - 16
      r = div(code, 36) * 51
      g = rem(div(code, 6), 6) * 51
      b = rem(code, 6) * 51
      {r, g, b}
    end,
    # Grayscale (232-255)
    232..255 => fn code ->
      value = (code - 232) * 10 + 8
      {value, value, value}
    end
  }

  # Text attributes
  @attributes %{
    0 => :reset,
    1 => :bold,
    2 => :faint,
    3 => :italic,
    4 => :underline,
    5 => :blink,
    6 => :rapid_blink,
    7 => :reverse,
    8 => :conceal,
    9 => :strikethrough,
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

  @doc """
  Processes an ANSI escape sequence and returns the updated terminal state.
  """
  def process_escape(emulator, sequence) do
    case parse_sequence(sequence) do
      {:cursor_move, x, y} ->
        Raxol.Terminal.Emulator.move_cursor(emulator, x, y)
      
      {:cursor_up, n} ->
        Raxol.Terminal.Emulator.move_cursor(emulator, emulator.cursor_x, emulator.cursor_y - n)
      
      {:cursor_down, n} ->
        Raxol.Terminal.Emulator.move_cursor(emulator, emulator.cursor_x, emulator.cursor_y + n)
      
      {:cursor_forward, n} ->
        Raxol.Terminal.Emulator.move_cursor(emulator, emulator.cursor_x + n, emulator.cursor_y)
      
      {:cursor_backward, n} ->
        Raxol.Terminal.Emulator.move_cursor(emulator, emulator.cursor_x - n, emulator.cursor_y)
      
      {:set_foreground, color} ->
        set_attribute(emulator, :foreground, color)
      
      {:set_background, color} ->
        set_attribute(emulator, :background, color)
      
      {:set_foreground_256, color} ->
        set_attribute(emulator, :foreground_256, color)
      
      {:set_background_256, color} ->
        set_attribute(emulator, :background_256, color)
      
      {:set_foreground_true, {r, g, b}} ->
        set_attribute(emulator, :foreground_true, {r, g, b})
      
      {:set_background_true, {r, g, b}} ->
        set_attribute(emulator, :background_true, {r, g, b})
      
      {:set_attribute, attr} ->
        set_attribute(emulator, attr, true)
      
      {:reset_attribute, attr} ->
        set_attribute(emulator, attr, false)
      
      {:clear_screen, mode} ->
        clear_screen(emulator, mode)
      
      {:erase_line, mode} ->
        erase_line(emulator, mode)
      
      {:insert_line, n} ->
        insert_line(emulator, n)
      
      {:delete_line, n} ->
        delete_line(emulator, n)
      
      {:set_scroll_region, top, bottom} ->
        set_scroll_region(emulator, top, bottom)
      
      {:save_cursor} ->
        save_cursor(emulator)
      
      {:restore_cursor} ->
        restore_cursor(emulator)
      
      {:show_cursor} ->
        show_cursor(emulator)
      
      {:hide_cursor} ->
        hide_cursor(emulator)
      
      _ ->
        emulator
    end
  end

  @doc """
  Generates an ANSI escape sequence for the given command and parameters.
  """
  def generate_sequence(command, params \\ []) do
    case command do
      :cursor_move ->
        [x, y] = params
        "\e[#{y};#{x}H"
      
      :cursor_up ->
        [n] = params
        "\e[#{n}A"
      
      :cursor_down ->
        [n] = params
        "\e[#{n}B"
      
      :cursor_forward ->
        [n] = params
        "\e[#{n}C"
      
      :cursor_backward ->
        [n] = params
        "\e[#{n}D"
      
      :set_foreground ->
        [color] = params
        "\e[#{color_code(color, :foreground)}m"
      
      :set_background ->
        [color] = params
        "\e[#{color_code(color, :background)}m"
      
      :set_foreground_256 ->
        [color] = params
        "\e[38;5;#{color}m"
      
      :set_background_256 ->
        [color] = params
        "\e[48;5;#{color}m"
      
      :set_foreground_true ->
        [{r, g, b}] = params
        "\e[38;2;#{r};#{g};#{b}m"
      
      :set_background_true ->
        [{r, g, b}] = params
        "\e[48;2;#{r};#{g};#{b}m"
      
      :set_attribute ->
        [attr] = params
        "\e[#{attribute_code(attr)}m"
      
      :reset_attribute ->
        [attr] = params
        "\e[#{reset_attribute_code(attr)}m"
      
      :clear_screen ->
        [mode] = params
        "\e[#{clear_screen_code(mode)}J"
      
      :erase_line ->
        [mode] = params
        "\e[#{erase_line_code(mode)}K"
      
      :insert_line ->
        [n] = params
        "\e[#{n}L"
      
      :delete_line ->
        [n] = params
        "\e[#{n}M"
      
      :set_scroll_region ->
        [top, bottom] = params
        "\e[#{top};#{bottom}r"
      
      :save_cursor ->
        "\e[s"
      
      :restore_cursor ->
        "\e[u"
      
      :show_cursor ->
        "\e[?25h"
      
      :hide_cursor ->
        "\e[?25l"
    end
  end

  # Private functions

  defp parse_sequence(sequence) do
    case sequence do
      <<"\e[", rest::binary>> ->
        parse_parameters(rest)
      
      <<"\e", rest::binary>> ->
        parse_single_char(rest)
      
      _ ->
        :unknown
    end
  end

  defp parse_parameters(sequence) do
    case String.split(sequence, ";") do
      [params, "H"] ->
        [x, y] = String.split(params) |> Enum.map(&String.to_integer/1)
        {:cursor_move, x, y}
      
      [params, "A"] ->
        {:cursor_up, String.to_integer(params)}
      
      [params, "B"] ->
        {:cursor_down, String.to_integer(params)}
      
      [params, "C"] ->
        {:cursor_forward, String.to_integer(params)}
      
      [params, "D"] ->
        {:cursor_backward, String.to_integer(params)}
      
      [params, "m"] ->
        parse_attributes(String.split(params))
      
      [params, "J"] ->
        {:clear_screen, String.to_integer(params)}
      
      [params, "K"] ->
        {:erase_line, String.to_integer(params)}
      
      [params, "L"] ->
        {:insert_line, String.to_integer(params)}
      
      [params, "M"] ->
        {:delete_line, String.to_integer(params)}
      
      [top, bottom, "r"] ->
        {:set_scroll_region, String.to_integer(top), String.to_integer(bottom)}
      
      _ ->
        :unknown
    end
  end

  defp parse_single_char("s"), do: {:save_cursor}
  defp parse_single_char("u"), do: {:restore_cursor}
  defp parse_single_char("?25h"), do: {:show_cursor}
  defp parse_single_char("?25l"), do: {:hide_cursor}
  defp parse_single_char(_), do: :unknown

  defp parse_attributes(codes) do
    Enum.reduce(codes, [], fn code, acc ->
      case String.to_integer(code) do
        # 256-color foreground
        n when n in 38..39 ->
          case Enum.at(codes, 1) do
            "5" -> # 256-color mode
              color = String.to_integer(Enum.at(codes, 2))
              [{:set_foreground_256, color} | acc]
            "2" -> # True color mode
              [r, g, b] = Enum.slice(codes, 2..4) |> Enum.map(&String.to_integer/1)
              [{:set_foreground_true, {r, g, b}} | acc]
            _ -> acc
          end
        
        # 256-color background
        n when n in 48..49 ->
          case Enum.at(codes, 1) do
            "5" -> # 256-color mode
              color = String.to_integer(Enum.at(codes, 2))
              [{:set_background_256, color} | acc]
            "2" -> # True color mode
              [r, g, b] = Enum.slice(codes, 2..4) |> Enum.map(&String.to_integer/1)
              [{:set_background_true, {r, g, b}} | acc]
            _ -> acc
          end
        
        # Standard colors and attributes
        n ->
          cond do
            # Foreground colors
            n in 30..37 ->
              [{:set_foreground, Map.get(@colors, n - 30)} | acc]
            n in 90..97 ->
              [{:set_foreground, Map.get(@colors, n - 82)} | acc]
            
            # Background colors
            n in 40..47 ->
              [{:set_background, Map.get(@colors, n - 40)} | acc]
            n in 100..107 ->
              [{:set_background, Map.get(@colors, n - 92)} | acc]
            
            # Text attributes
            Map.has_key?(@attributes, n) ->
              attr = Map.get(@attributes, n)
              if n == 0 do
                [{:reset_all} | acc]
              else
                [{:set_attribute, attr} | acc]
              end
            
            true ->
              acc
          end
      end
    end)
  end

  defp set_attribute(emulator, attr, value) do
    new_attributes = Map.put(emulator.attributes, attr, value)
    %{emulator | attributes: new_attributes}
  end

  defp color_code(color, type) do
    base = case type do
      :foreground -> 30
      :background -> 40
    end
    
    case color do
      :black -> base + 0
      :red -> base + 1
      :green -> base + 2
      :yellow -> base + 3
      :blue -> base + 4
      :magenta -> base + 5
      :cyan -> base + 6
      :white -> base + 7
      :bright_black -> base + 60
      :bright_red -> base + 61
      :bright_green -> base + 62
      :bright_yellow -> base + 63
      :bright_blue -> base + 64
      :bright_magenta -> base + 65
      :bright_cyan -> base + 66
      :bright_white -> base + 67
      _ -> base + 7  # Default to white
    end
  end

  defp attribute_code(attr) do
    case attr do
      :bold -> "1"
      :faint -> "2"
      :italic -> "3"
      :underline -> "4"
      :blink -> "5"
      :rapid_blink -> "6"
      :reverse -> "7"
      :conceal -> "8"
      :strikethrough -> "9"
      :fraktur -> "20"
      :double_underline -> "21"
      :normal_intensity -> "22"
      :no_italic_fraktur -> "23"
      :no_underline -> "24"
      :no_blink -> "25"
      :no_reverse -> "27"
      :reveal -> "28"
      :no_strikethrough -> "29"
      _ -> "0"
    end
  end

  defp reset_attribute_code(attr) do
    case attr do
      :bold -> "22"
      :faint -> "22"
      :italic -> "23"
      :underline -> "24"
      :blink -> "25"
      :rapid_blink -> "25"
      :reverse -> "27"
      :conceal -> "28"
      :strikethrough -> "29"
      :fraktur -> "23"
      :double_underline -> "24"
      :normal_intensity -> "22"
      :no_italic_fraktur -> "23"
      :no_underline -> "24"
      :no_blink -> "25"
      :no_reverse -> "27"
      :reveal -> "28"
      :no_strikethrough -> "29"
      _ -> "0"
    end
  end

  defp clear_screen_code(mode) do
    case mode do
      0 -> "0"  # Clear from cursor to end
      1 -> "1"  # Clear from beginning to cursor
      2 -> "2"  # Clear entire screen
      3 -> "3"  # Clear entire screen and scrollback
      _ -> "0"
    end
  end

  defp erase_line_code(mode) do
    case mode do
      0 -> "0"  # Clear from cursor to end of line
      1 -> "1"  # Clear from beginning of line to cursor
      2 -> "2"  # Clear entire line
      _ -> "0"
    end
  end

  defp insert_line(emulator, n) do
    # Implementation will be added to Emulator module
    emulator
  end

  defp delete_line(emulator, n) do
    # Implementation will be added to Emulator module
    emulator
  end

  defp set_scroll_region(emulator, top, bottom) do
    # Implementation will be added to Emulator module
    emulator
  end

  defp save_cursor(emulator) do
    # Implementation will be added to Emulator module
    emulator
  end

  defp restore_cursor(emulator) do
    # Implementation will be added to Emulator module
    emulator
  end

  defp show_cursor(emulator) do
    # Implementation will be added to Emulator module
    emulator
  end

  defp hide_cursor(emulator) do
    # Implementation will be added to Emulator module
    emulator
  end

  # Color conversion utilities

  @doc """
  Converts a hex color string to RGB tuple.
  
  ## Examples
  
      iex> ANSI.hex_to_rgb("#FF0000")
      {255, 0, 0}
      
      iex> ANSI.hex_to_rgb("#00FF00")
      {0, 255, 0}
      
      iex> ANSI.hex_to_rgb("#0000FF")
      {0, 0, 255}
  """
  def hex_to_rgb(hex) do
    hex = String.replace(hex, ~r/^#/, "")
    
    case String.length(hex) do
      3 -> # Short hex (e.g., #F00)
        r = String.slice(hex, 0..0) |> String.duplicate(2) |> String.to_integer(16)
        g = String.slice(hex, 1..1) |> String.duplicate(2) |> String.to_integer(16)
        b = String.slice(hex, 2..2) |> String.duplicate(2) |> String.to_integer(16)
        {r, g, b}
      
      6 -> # Full hex (e.g., #FF0000)
        r = String.slice(hex, 0..1) |> String.to_integer(16)
        g = String.slice(hex, 2..3) |> String.to_integer(16)
        b = String.slice(hex, 4..5) |> String.to_integer(16)
        {r, g, b}
      
      _ -> {0, 0, 0} # Default to black for invalid hex
    end
  end

  @doc """
  Converts an RGB tuple to a hex color string.
  
  ## Examples
  
      iex> ANSI.rgb_to_hex({255, 0, 0})
      "#FF0000"
      
      iex> ANSI.rgb_to_hex({0, 255, 0})
      "#00FF00"
      
      iex> ANSI.rgb_to_hex({0, 0, 255})
      "#0000FF"
  """
  def rgb_to_hex({r, g, b}) do
    "#" <> 
    Integer.to_string(r, 16) |> String.pad_leading(2, "0") <>
    Integer.to_string(g, 16) |> String.pad_leading(2, "0") <>
    Integer.to_string(b, 16) |> String.pad_leading(2, "0")
  end

  @doc """
  Converts an RGB color to the closest 256-color mode index.
  
  ## Examples
  
      iex> ANSI.rgb_to_256({0, 0, 0})
      16
      
      iex> ANSI.rgb_to_256({255, 255, 255})
      231
      
      iex> ANSI.rgb_to_256({128, 128, 128})
      244
  """
  def rgb_to_256({r, g, b}) do
    # Find the closest color in the 256-color palette
    Enum.reduce(@color_256_palette, {16, Float.infinity()}, fn {range, converter}, {best_code, min_diff} ->
      Enum.reduce(range, {best_code, min_diff}, fn code, {best, min} ->
        rgb = converter.(code)
        diff = color_distance({r, g, b}, rgb)
        if diff < min do
          {code, diff}
        else
          {best, min}
        end
      end)
    end)
    |> elem(0)
  end

  @doc """
  Converts a hex color to the closest 256-color mode index.
  
  ## Examples
  
      iex> ANSI.hex_to_256("#000000")
      16
      
      iex> ANSI.hex_to_256("#FFFFFF")
      231
      
      iex> ANSI.hex_to_256("#808080")
      244
  """
  def hex_to_256(hex) do
    hex
    |> hex_to_rgb()
    |> rgb_to_256()
  end

  @doc """
  Blends two RGB colors with the given alpha value (0.0 to 1.0).
  
  ## Examples
  
      iex> ANSI.blend_rgb({255, 0, 0}, {0, 0, 255}, 0.5)
      {127, 0, 127}
      
      iex> ANSI.blend_rgb({255, 255, 255}, {0, 0, 0}, 0.25)
      {191, 191, 191}
  """
  def blend_rgb({r1, g1, b1}, {r2, g2, b2}, alpha) do
    alpha = max(0.0, min(1.0, alpha))
    r = round(r1 * (1 - alpha) + r2 * alpha)
    g = round(g1 * (1 - alpha) + g2 * alpha)
    b = round(b1 * (1 - alpha) + b2 * alpha)
    {r, g, b}
  end

  @doc """
  Blends two hex colors with the given alpha value (0.0 to 1.0).
  
  ## Examples
  
      iex> ANSI.blend_hex("#FF0000", "#0000FF", 0.5)
      "#7F007F"
      
      iex> ANSI.blend_hex("#FFFFFF", "#000000", 0.25)
      "#BFBFBF"
  """
  def blend_hex(hex1, hex2, alpha) do
    rgb1 = hex_to_rgb(hex1)
    rgb2 = hex_to_rgb(hex2)
    blend_rgb(rgb1, rgb2, alpha)
    |> rgb_to_hex()
  end

  @doc """
  Converts an RGB color to HSL (Hue, Saturation, Lightness).
  
  ## Examples
  
      iex> ANSI.rgb_to_hsl({255, 0, 0})
      {0, 1.0, 0.5}
      
      iex> ANSI.rgb_to_hsl({0, 255, 0})
      {120, 1.0, 0.5}
      
      iex> ANSI.rgb_to_hsl({0, 0, 255})
      {240, 1.0, 0.5}
  """
  def rgb_to_hsl({r, g, b}) do
    r = r / 255
    g = g / 255
    b = b / 255
    
    max_val = max(max(r, g), b)
    min_val = min(min(r, g), b)
    
    delta = max_val - min_val
    
    # Calculate lightness
    l = (max_val + min_val) / 2
    
    # Calculate saturation
    s = if delta == 0 do
      0
    else
      delta / (1 - abs(2 * l - 1))
    end
    
    # Calculate hue
    h = cond do
      delta == 0 -> 0
      max_val == r -> 60 * rem(rem(((g - b) / delta), 6), 6)
      max_val == g -> 60 * ((b - r) / delta + 2)
      max_val == b -> 60 * ((r - g) / delta + 4)
    end
    
    {h, s, l}
  end

  @doc """
  Converts HSL (Hue, Saturation, Lightness) to RGB.
  
  ## Examples
  
      iex> ANSI.hsl_to_rgb({0, 1.0, 0.5})
      {255, 0, 0}
      
      iex> ANSI.hsl_to_rgb({120, 1.0, 0.5})
      {0, 255, 0}
      
      iex> ANSI.hsl_to_rgb({240, 1.0, 0.5})
      {0, 0, 255}
  """
  def hsl_to_rgb({h, s, l}) do
    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(rem(h / 60, 2) - 1))
    m = l - c / 2
    
    {r, g, b} = cond do
      h < 60 -> {c, x, 0}
      h < 120 -> {x, c, 0}
      h < 180 -> {0, c, x}
      h < 240 -> {0, x, c}
      h < 300 -> {x, 0, c}
      true -> {c, 0, x}
    end
    
    {
      round((r + m) * 255),
      round((g + m) * 255),
      round((b + m) * 255)
    }
  end

  @doc """
  Converts a hex color to HSL.
  
  ## Examples
  
      iex> ANSI.hex_to_hsl("#FF0000")
      {0, 1.0, 0.5}
      
      iex> ANSI.hex_to_hsl("#00FF00")
      {120, 1.0, 0.5}
      
      iex> ANSI.hex_to_hsl("#0000FF")
      {240, 1.0, 0.5}
  """
  def hex_to_hsl(hex) do
    hex
    |> hex_to_rgb()
    |> rgb_to_hsl()
  end

  @doc """
  Converts HSL to a hex color.
  
  ## Examples
  
      iex> ANSI.hsl_to_hex({0, 1.0, 0.5})
      "#FF0000"
      
      iex> ANSI.hsl_to_hex({120, 1.0, 0.5})
      "#00FF00"
      
      iex> ANSI.hsl_to_hex({240, 1.0, 0.5})
      "#0000FF"
  """
  def hsl_to_hex({h, s, l}) do
    {h, s, l}
    |> hsl_to_rgb()
    |> rgb_to_hex()
  end

  @doc """
  Adjusts the brightness of an RGB color.
  
  ## Examples
  
      iex> ANSI.adjust_brightness({255, 0, 0}, 0.5)
      {127, 0, 0}
      
      iex> ANSI.adjust_brightness({0, 255, 0}, 1.5)
      {0, 255, 0}
  """
  def adjust_brightness({r, g, b}, factor) do
    factor = max(0.0, factor)
    {
      min(255, round(r * factor)),
      min(255, round(g * factor)),
      min(255, round(b * factor))
    }
  end

  @doc """
  Adjusts the brightness of a hex color.
  
  ## Examples
  
      iex> ANSI.adjust_brightness_hex("#FF0000", 0.5)
      "#7F0000"
      
      iex> ANSI.adjust_brightness_hex("#00FF00", 1.5)
      "#00FF00"
  """
  def adjust_brightness_hex(hex, factor) do
    hex
    |> hex_to_rgb()
    |> adjust_brightness(factor)
    |> rgb_to_hex()
  end

  @doc """
  Calculates the distance between two RGB colors.
  
  ## Examples
  
      iex> ANSI.color_distance({255, 0, 0}, {0, 0, 0})
      255.0
      
      iex> ANSI.color_distance({255, 0, 0}, {255, 0, 0})
      0.0
  """
  def color_distance({r1, g1, b1}, {r2, g2, b2}) do
    :math.sqrt(
      :math.pow(r1 - r2, 2) +
      :math.pow(g1 - g2, 2) +
      :math.pow(b1 - b2, 2)
    )
  end

  @doc """
  Generates a sequence of colors between two RGB colors.
  
  ## Examples
  
      iex> ANSI.color_gradient({255, 0, 0}, {0, 0, 255}, 5)
      [{255, 0, 0}, {191, 0, 63}, {127, 0, 127}, {63, 0, 191}, {0, 0, 255}]
  """
  def color_gradient({r1, g1, b1}, {r2, g2, b2}, steps) do
    steps = max(2, steps)
    step_size = 1.0 / (steps - 1)
    
    Enum.map(0..(steps-1), fn i ->
      alpha = i * step_size
      blend_rgb({r1, g1, b1}, {r2, g2, b2}, alpha)
    end)
  end

  @doc """
  Generates a sequence of hex colors between two hex colors.
  
  ## Examples
  
      iex> ANSI.color_gradient_hex("#FF0000", "#0000FF", 5)
      ["#FF0000", "#BF003F", "#7F007F", "#3F00BF", "#0000FF"]
  """
  def color_gradient_hex(hex1, hex2, steps) do
    rgb1 = hex_to_rgb(hex1)
    rgb2 = hex_to_rgb(hex2)
    
    color_gradient(rgb1, rgb2, steps)
    |> Enum.map(&rgb_to_hex/1)
  end
end 