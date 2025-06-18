defmodule Raxol.Terminal.Style.Manager do
  @moduledoc '''
  Manages text styling and formatting for the terminal emulator.
  This module provides a clean interface for managing text styles, colors, and attributes.
  '''

  alias Raxol.Terminal.ANSI.TextFormatting

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

  @doc '''
  Creates a new text style with default values.
  '''
  @spec new() :: text_style()
  def new do
    TextFormatting.new()
  end

  @doc '''
  Gets the current style.
  '''
  @spec get_current_style(text_style()) :: text_style()
  def get_current_style(style) do
    style
  end

  @doc '''
  Sets the style to a new value.
  '''
  @spec set_style(text_style(), text_style()) :: text_style()
  def set_style(_current_style, new_style) do
    new_style
  end

  @doc '''
  Applies a text attribute to the style.
  '''
  @spec apply_style(text_style(), atom()) :: text_style()
  def apply_style(style, attribute) do
    TextFormatting.apply_attribute(style, attribute)
  end

  @doc '''
  Resets all text formatting attributes to their default values.
  '''
  @spec reset_style(text_style()) :: text_style()
  def reset_style(_style) do
    new()
  end

  @doc '''
  Sets the foreground color.
  '''
  @spec set_foreground(text_style(), color()) :: text_style()
  def set_foreground(style, color) do
    TextFormatting.set_foreground(style, color)
  end

  @doc '''
  Sets the background color.
  '''
  @spec set_background(text_style(), color()) :: text_style()
  def set_background(style, color) do
    TextFormatting.set_background(style, color)
  end

  @doc '''
  Gets the foreground color.
  '''
  @spec get_foreground(text_style()) :: color()
  def get_foreground(style) do
    TextFormatting.get_foreground(style)
  end

  @doc '''
  Gets the background color.
  '''
  @spec get_background(text_style()) :: color()
  def get_background(style) do
    TextFormatting.get_background(style)
  end

  @doc '''
  Sets double-width mode for the current line.
  '''
  @spec set_double_width(text_style()) :: text_style()
  def set_double_width(style) do
    TextFormatting.set_double_width(style)
  end

  @doc '''
  Sets double-height top half mode for the current line.
  '''
  @spec set_double_height_top(text_style()) :: text_style()
  def set_double_height_top(style) do
    TextFormatting.set_double_height_top(style)
  end

  @doc '''
  Sets double-height bottom half mode for the current line.
  '''
  @spec set_double_height_bottom(text_style()) :: text_style()
  def set_double_height_bottom(style) do
    TextFormatting.set_double_height_bottom(style)
  end

  @doc '''
  Resets to single-width, single-height mode.
  '''
  @spec reset_size(text_style()) :: text_style()
  def reset_size(style) do
    TextFormatting.reset_size(style)
  end

  @doc '''
  Calculates the effective width of a character based on the current style.
  '''
  @spec effective_width(text_style(), String.t()) :: integer()
  def effective_width(style, char) do
    TextFormatting.effective_width(style, char)
  end

  @doc '''
  Gets the hyperlink URI.
  '''
  @spec get_hyperlink(text_style()) :: String.t() | nil
  def get_hyperlink(style) do
    TextFormatting.get_hyperlink(style)
  end

  @doc '''
  Sets a hyperlink URI.
  '''
  @spec set_hyperlink(text_style(), String.t() | nil) :: text_style()
  def set_hyperlink(style, url) do
    TextFormatting.set_hyperlink(style, url)
  end

  @doc '''
  Converts an ANSI color code to a color name.
  '''
  @spec ansi_code_to_color_name(integer()) :: color() | nil
  def ansi_code_to_color_name(code) do
    TextFormatting.ansi_code_to_color_name(code)
  end

  @doc '''
  Formats SGR parameters for DECRQSS responses.
  '''
  @spec format_sgr_params(text_style()) :: String.t()
  def format_sgr_params(style) do
    TextFormatting.format_sgr_params(style)
  end
end
