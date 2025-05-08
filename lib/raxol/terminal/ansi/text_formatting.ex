defmodule Raxol.Terminal.ANSI.TextFormatting do
  @moduledoc """
  Handles advanced text formatting features for the terminal emulator.
  This includes double-width and double-height characters, as well as
  other advanced text attributes and colors.
  """

  @type color ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | {:index, non_neg_integer()}
          | nil

  @type text_style :: %{
          double_width: boolean(),
          double_height: :none | :top | :bottom,
          bold: boolean(),
          faint: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          fraktur: boolean(),
          double_underline: boolean(),
          foreground: color(),
          background: color(),
          hyperlink: String.t() | nil
        }

  @doc """
  Creates a new text style map with default values.
  """
  @spec new() :: %{
          double_width: false,
          double_height: :none,
          bold: false,
          faint: false,
          italic: false,
          underline: false,
          blink: false,
          reverse: false,
          conceal: false,
          strikethrough: false,
          fraktur: false,
          double_underline: false,
          foreground: nil,
          background: nil,
          hyperlink: nil
        }
  def new do
    %{
      double_width: false,
      double_height: :none,
      bold: false,
      faint: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false,
      conceal: false,
      strikethrough: false,
      fraktur: false,
      double_underline: false,
      foreground: nil,
      background: nil,
      hyperlink: nil
    }
  end

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(text_style(), color()) :: text_style()
  def set_foreground(style, color) do
    %{style | foreground: color}
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(text_style(), color()) :: text_style()
  def set_background(style, color) do
    %{style | background: color}
  end

  @doc """
  Gets the foreground color.
  """
  @spec get_foreground(text_style()) :: color()
  def get_foreground(%{} = style) do
    style.foreground
  end

  @doc """
  Gets the background color.
  """
  @spec get_background(text_style()) :: color()
  def get_background(%{} = style) do
    style.background
  end

  @doc """
  Sets double-width mode for the current line.
  """
  @spec set_double_width(text_style()) :: text_style()
  def set_double_width(style) do
    %{style | double_width: true, double_height: :none}
  end

  @doc """
  Sets double-height top half mode for the current line.
  """
  @spec set_double_height_top(text_style()) :: text_style()
  def set_double_height_top(style) do
    %{style | double_width: true, double_height: :top}
  end

  @doc """
  Sets double-height bottom half mode for the current line.
  """
  @spec set_double_height_bottom(text_style()) :: text_style()
  def set_double_height_bottom(style) do
    %{style | double_width: true, double_height: :bottom}
  end

  @doc """
  Resets to single-width, single-height mode.
  """
  @spec reset_size(text_style()) :: text_style()
  def reset_size(style) do
    %{style | double_width: false, double_height: :none}
  end

  @doc """
  Applies a text attribute to the style map.
  """
  @spec apply_attribute(text_style(), atom()) :: text_style()
  def apply_attribute(style, attribute) do
    case attribute do
      :reset ->
        new()

      :double_width ->
        set_double_width(style)

      :double_height_top ->
        set_double_height_top(style)

      :double_height_bottom ->
        set_double_height_bottom(style)

      :no_double_width ->
        %{style | double_width: false}

      :no_double_height ->
        %{style | double_height: :none}

      :bold ->
        %{style | bold: true}

      :faint ->
        %{style | faint: true}

      :italic ->
        %{style | italic: true}

      :underline ->
        %{style | underline: true}

      :blink ->
        %{style | blink: true}

      :reverse ->
        %{style | reverse: true}

      :conceal ->
        %{style | conceal: true}

      :strikethrough ->
        %{style | strikethrough: true}

      :fraktur ->
        %{style | fraktur: true}

      :double_underline ->
        %{style | double_underline: true}

      :normal_intensity ->
        %{style | bold: false, faint: false}

      :no_italic_fraktur ->
        %{style | italic: false, fraktur: false}

      :no_underline ->
        new_style = %{style | underline: false, double_underline: false}
        new_style

      :no_blink ->
        %{style | blink: false}

      :no_reverse ->
        %{style | reverse: false}

      :reveal ->
        %{style | conceal: false}

      :no_strikethrough ->
        %{style | strikethrough: false}

      :black ->
        %{style | foreground: :black}

      :red ->
        %{style | foreground: :red}

      :green ->
        %{style | foreground: :green}

      :yellow ->
        %{style | foreground: :yellow}

      :blue ->
        %{style | foreground: :blue}

      :magenta ->
        %{style | foreground: :magenta}

      :cyan ->
        %{style | foreground: :cyan}

      :white ->
        %{style | foreground: :white}

      :bg_black ->
        %{style | background: :black}

      :bg_red ->
        %{style | background: :red}

      :bg_green ->
        %{style | background: :green}

      :bg_yellow ->
        %{style | background: :yellow}

      :bg_blue ->
        %{style | background: :blue}

      :bg_magenta ->
        %{style | background: :magenta}

      :bg_cyan ->
        %{style | background: :cyan}

      :bg_white ->
        %{style | background: :white}

      :default_fg ->
        %{style | foreground: nil}

      :default_bg ->
        %{style | background: nil}

      _ ->
        style
    end
  end

  @doc """
  Applies a color attribute to the style map.
  """
  @spec apply_color(text_style(), :foreground | :background, color()) ::
          text_style()
  def apply_color(style, type, color) do
    case type do
      :foreground -> set_foreground(style, color)
      :background -> set_background(style, color)
      _ -> style
    end
  end

  @doc """
  Calculates the effective width of a character based on the current style.
  """
  @spec effective_width(text_style(), String.t()) :: integer()
  def effective_width(%{} = style, char) do
    cond do
      style.double_width ->
        2

      # Basic check for wide characters (CJK range approximation)
      true ->
        case String.to_charlist(char) do
          [codepoint] ->
            # CJK Unified Ideographs, Hangul Syllables, Hiragana, Katakana, etc.
            # This is an approximation and might not cover all wide chars.
            # CJK Unified Ideographs
            # Hangul Syllables
            # Hiragana, Katakana
            # Fullwidth Forms
            if (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or
                 (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or
                 (codepoint >= 0x3040 and codepoint <= 0x30FF) or
                 (codepoint >= 0xFF00 and codepoint <= 0xFFEF) do
              2
            else
              1
            end

          # Handle multi-grapheme characters or empty string as width 1 (or adjust as needed)
          _ ->
            1
        end
    end
  end

  @doc """
  Determines if the current line needs a paired line (for double-height mode).
  """
  @spec needs_paired_line?(text_style()) :: boolean()
  def needs_paired_line?(%{} = style) do
    style.double_height != :none
  end

  @doc """
  Gets the paired line type for double-height mode.
  """
  @spec get_paired_line_type(text_style()) :: :top | :bottom | :none
  def get_paired_line_type(%{double_height: :top}) do
    :bottom
  end

  def get_paired_line_type(%{double_height: :bottom}) do
    :top
  end

  def get_paired_line_type(%{double_height: :none}) do
    # The test "paired_line_type returns nil for :none" expects nil
    nil
  end

  # Fallback for any other style, though ideally covered by :none
  def get_paired_line_type(_style) do
    nil
  end

  @doc """
  Converts a standard ANSI 3/4-bit color code to a color name atom.

  ## Examples

      iex> Raxol.Terminal.ANSI.TextFormatting.ansi_code_to_color_name(31)
      :red

      iex> Raxol.Terminal.ANSI.TextFormatting.ansi_code_to_color_name(44)
      :blue

      iex> Raxol.Terminal.ANSI.TextFormatting.ansi_code_to_color_name(99) # Unknown
      nil

  """
  @spec ansi_code_to_color_name(integer()) :: color() | nil
  def ansi_code_to_color_name(code) do
    case code do
      30 -> :black
      31 -> :red
      32 -> :green
      33 -> :yellow
      34 -> :blue
      35 -> :magenta
      36 -> :cyan
      37 -> :white
      40 -> :black
      41 -> :red
      42 -> :green
      43 -> :yellow
      44 -> :blue
      45 -> :magenta
      46 -> :cyan
      47 -> :white
      # TODO: Add bright color codes (90-97, 100-107) if needed and map them appropriately
      # For now, map them to nil or their base color
      # Or handle bright colors if desired
      _ -> nil
    end
  end

  @doc """
  Resets all text formatting attributes to their default values.
  """
  @spec reset(text_style()) :: text_style()
  def reset(_style) do
    new()
  end

  def set_hyperlink(style, url) do
    %{style | hyperlink: url}
  end

  @doc """
  Reconstructs the SGR parameter string corresponding to the given style attributes.
  Used primarily for DECRQSS responses.
  """
  @spec format_sgr_params(text_style()) :: String.t()
  def format_sgr_params(attrs) do
    # Reconstruct SGR parameters from current attributes map
    params = []
    params = if attrs.bold, do: [1 | params], else: params
    # Added faint
    params = if attrs.faint, do: [2 | params], else: params
    params = if attrs.italic, do: [3 | params], else: params
    params = if attrs.underline, do: [4 | params], else: params
    # Added blink
    params = if attrs.blink, do: [5 | params], else: params
    # Renamed from inverse
    params = if attrs.reverse, do: [7 | params], else: params
    # Added conceal
    params = if attrs.conceal, do: [8 | params], else: params
    # Added strikethrough
    params = if attrs.strikethrough, do: [9 | params], else: params
    # Added fraktur
    params = if attrs.fraktur, do: [20 | params], else: params
    # Added double_underline
    params = if attrs.double_underline, do: [21 | params], else: params

    # Note: Resets (like 22, 24, 25 etc.) aren't typically included when reporting state.

    # Add foreground color
    params =
      case attrs.fg do
        {:ansi, n} when n >= 0 and n <= 7 -> [30 + n | params]
        {:ansi, n} when n >= 8 and n <= 15 -> [90 + (n - 8) | params]
        {:color_256, n} -> [38, 5, n | params]
        {:rgb, r, g, b} -> [38, 2, r, g, b | params]
        # or maybe 39? Needs verification based on terminal behavior.
        :default -> params
      end

    # Add background color
    params =
      case attrs.bg do
        {:ansi, n} when n >= 0 and n <= 7 -> [40 + n | params]
        {:ansi, n} when n >= 8 and n <= 15 -> [100 + (n - 8) | params]
        {:color_256, n} -> [48, 5, n | params]
        {:rgb, r, g, b} -> [48, 2, r, g, b | params]
        # or maybe 49? Needs verification.
        :default -> params
      end

    # Handle reset case (if no attributes set, send 0)
    if params == [] do
      "0"
    else
      Enum.reverse(params) |> Enum.map_join(&Integer.to_string/1, ";")
    end
  end

  @doc """
  Gets the hyperlink URI.
  """
  @spec get_hyperlink(text_style()) :: String.t() | nil
  def get_hyperlink(%{} = style) do
    style.hyperlink
  end

  @doc """
  Helper to parse a single SGR parameter.
  """
  defp parse_sgr_param(param, %{} = current_style) do
    case param do
      # Reset
      # Reset all attributes
      0 ->
        new()

      1 ->
        apply_attribute(current_style, :bold)

      2 ->
        apply_attribute(current_style, :faint)

      3 ->
        apply_attribute(current_style, :italic)

      4 ->
        apply_attribute(current_style, :underline)

      5 ->
        apply_attribute(current_style, :blink)

      7 ->
        apply_attribute(current_style, :reverse)

      8 ->
        apply_attribute(current_style, :conceal)

      9 ->
        apply_attribute(current_style, :strikethrough)

      20 ->
        apply_attribute(current_style, :fraktur)

      21 ->
        apply_attribute(current_style, :double_underline)

      22 ->
        apply_attribute(current_style, :normal_intensity)

      23 ->
        apply_attribute(current_style, :no_italic_fraktur)

      24 ->
        apply_attribute(current_style, :no_underline)

      25 ->
        apply_attribute(current_style, :no_blink)

      27 ->
        apply_attribute(current_style, :no_reverse)

      28 ->
        apply_attribute(current_style, :reveal)

      29 ->
        apply_attribute(current_style, :no_strikethrough)

      30 ->
        apply_attribute(current_style, :black)

      31 ->
        apply_attribute(current_style, :red)

      32 ->
        apply_attribute(current_style, :green)

      33 ->
        apply_attribute(current_style, :yellow)

      34 ->
        apply_attribute(current_style, :blue)

      35 ->
        apply_attribute(current_style, :magenta)

      36 ->
        apply_attribute(current_style, :cyan)

      37 ->
        apply_attribute(current_style, :white)

      38 ->
        apply_attribute(current_style, :default_fg)

      39 ->
        apply_attribute(current_style, :default_fg)

      40 ->
        apply_attribute(current_style, :bg_black)

      41 ->
        apply_attribute(current_style, :bg_red)

      42 ->
        apply_attribute(current_style, :bg_green)

      43 ->
        apply_attribute(current_style, :bg_yellow)

      44 ->
        apply_attribute(current_style, :bg_blue)

      45 ->
        apply_attribute(current_style, :bg_magenta)

      46 ->
        apply_attribute(current_style, :bg_cyan)

      47 ->
        apply_attribute(current_style, :bg_white)

      48 ->
        apply_attribute(current_style, :default_bg)

      49 ->
        apply_attribute(current_style, :default_bg)

      # Set Foreground Color (8-bit)
      {:fg_8bit, index} when index >= 0 and index <= 255 ->
        apply_color(current_style, :foreground, {:index, index})

      # Set Background Color (8-bit)
      {:bg_8bit, index} when index >= 0 and index <= 255 ->
        apply_color(current_style, :background, {:index, index})

      # Set Foreground Color (24-bit)
      {:fg_rgb, r, g, b} ->
        apply_color(current_style, :foreground, {:rgb, r, g, b})

      # Set Background Color (24-bit)
      {:bg_rgb, r, g, b} ->
        apply_color(current_style, :background, {:rgb, r, g, b})

      # Unknown/Ignored
      _ ->
        current_style
    end
  end
end
