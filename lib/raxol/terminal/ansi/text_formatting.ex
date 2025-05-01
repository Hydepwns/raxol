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
  def get_foreground(style) do
    style.foreground
  end

  @doc """
  Gets the background color.
  """
  @spec get_background(text_style()) :: color()
  def get_background(style) do
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
      :reset -> new()
      :double_width -> set_double_width(style)
      :double_height_top -> set_double_height_top(style)
      :double_height_bottom -> set_double_height_bottom(style)
      :no_double_width -> %{style | double_width: false}
      :no_double_height -> %{style | double_height: :none}
      :bold -> %{style | bold: true}
      :faint -> %{style | bold: false}
      :italic -> %{style | italic: true}
      :underline -> %{style | underline: true}
      :blink -> %{style | blink: true}
      :reverse -> %{style | reverse: true}
      :conceal -> %{style | conceal: true}
      :strikethrough -> %{style | strikethrough: true}
      :fraktur -> %{style | fraktur: true}
      :double_underline -> %{style | double_underline: true}
      :normal_intensity -> %{style | bold: false}
      :no_italic_fraktur -> %{style | italic: false, fraktur: false}
      :no_underline -> %{style | underline: false, double_underline: false}
      :no_blink -> %{style | blink: false}
      :no_reverse -> %{style | reverse: false}
      :reveal -> %{style | conceal: false}
      :no_strikethrough -> %{style | strikethrough: false}
      :black -> %{style | foreground: :black}
      :red -> %{style | foreground: :red}
      :green -> %{style | foreground: :green}
      :yellow -> %{style | foreground: :yellow}
      :blue -> %{style | foreground: :blue}
      :magenta -> %{style | foreground: :magenta}
      :cyan -> %{style | foreground: :cyan}
      :white -> %{style | foreground: :white}
      :bg_black -> %{style | background: :black}
      :bg_red -> %{style | background: :red}
      :bg_green -> %{style | background: :green}
      :bg_yellow -> %{style | background: :yellow}
      :bg_blue -> %{style | background: :blue}
      :bg_magenta -> %{style | background: :magenta}
      :bg_cyan -> %{style | background: :cyan}
      :bg_white -> %{style | background: :white}
      :default_fg -> %{style | foreground: nil}
      :default_bg -> %{style | background: nil}
      _ -> style
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
  def effective_width(style, char) do
    cond do
      style.double_width -> 2
      # Basic check for wide characters (CJK range approximation)
      case String.to_charlist(char) do
        [codepoint] ->
          # CJK Unified Ideographs, Hangul Syllables, Hiragana, Katakana, etc.
          # This is an approximation and might not cover all wide chars.
          if (codepoint >= 0x4E00 and codepoint <= 0x9FFF) or # CJK Unified Ideographs
             (codepoint >= 0xAC00 and codepoint <= 0xD7A3) or # Hangul Syllables
             (codepoint >= 0x3040 and codepoint <= 0x30FF) or # Hiragana, Katakana
             (codepoint >= 0xFF00 and codepoint <= 0xFFEF) # Fullwidth Forms
          do
            2
          else
            1
          end
        # Handle multi-grapheme characters or empty string as width 1 (or adjust as needed)
        _ -> 1
      end
      # This case is now handled by the char check above
      # String.length(char) > 1 -> 2
      # true -> 1
    end
  end

  @doc """
  Determines if the current line needs a paired line (for double-height mode).
  """
  @spec needs_paired_line?(text_style()) :: boolean()
  def needs_paired_line?(style) do
    style.double_height != :none
  end

  @doc """
  Gets the paired line type for double-height mode.
  """
  @spec paired_line_type(text_style()) :: :top | :bottom | nil
  def paired_line_type(style) do
    case style.double_height do
      :top -> :bottom
      :bottom -> :top
      :none -> nil
    end
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
end
