defmodule Raxol.Terminal.ANSI.TextFormatting do
  @moduledoc """
  Handles advanced text formatting features for the terminal emulator.
  This includes double-width and double-height characters, as well as
  other advanced text attributes and colors.
  """

  @type color :: :black | :red | :green | :yellow | :blue | :magenta | :cyan | :white |
                 {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()} |
                 {:index, non_neg_integer()} |
                 nil

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
    background: color()
  }

  @doc """
  Creates a new text style map with default values.
  """
  @spec new() :: text_style()
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
      background: nil
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
  @spec apply_color(text_style(), :foreground | :background, color()) :: text_style()
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
      String.length(char) > 1 -> 2  # Handle wide Unicode characters
      true -> 1
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
end
