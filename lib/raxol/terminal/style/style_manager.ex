defmodule Raxol.Terminal.Style.Manager do
  @moduledoc """
  Manages text styling and formatting for the terminal emulator.
  This module provides a clean interface for managing text styles, colors, and attributes.
  """

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
          background: color(),
          blink: boolean(),
          bold: boolean(),
          conceal: boolean(),
          double_height: :bottom | :none | :top,
          double_underline: boolean(),
          double_width: boolean(),
          encircled: boolean(),
          faint: boolean(),
          foreground: color(),
          fraktur: boolean(),
          framed: boolean(),
          hyperlink: nil | binary(),
          italic: boolean(),
          overlined: boolean(),
          reverse: boolean(),
          strikethrough: boolean(),
          underline: boolean()
        }

  @doc """
  Creates a new text style with default values.
  """
  @spec new() :: TextFormatting.t()
  def new do
    TextFormatting.new()
  end

  @doc """
  Gets the current style.
  """
  @spec get_current_style(TextFormatting.t()) :: TextFormatting.t()
  def get_current_style(style) do
    style
  end

  @doc """
  Sets the style to a new value.
  """
  @spec set_style(TextFormatting.t(), TextFormatting.t()) :: TextFormatting.t()
  def set_style(_current_style, new_style) do
    new_style
  end

  @doc """
  Applies a text attribute to the style.
  """
  @spec apply_style(TextFormatting.t(), atom()) :: TextFormatting.t()
  def apply_style(style, attribute) do
    TextFormatting.apply_attribute(style, attribute)
  end

  @doc """
  Resets all text formatting attributes to their default values.
  """
  @spec reset_style(TextFormatting.t()) :: TextFormatting.t()
  def reset_style(_style) do
    new()
  end

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(TextFormatting.t(), color()) :: TextFormatting.t()
  def set_foreground(style, color) do
    TextFormatting.set_foreground(style, color)
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(TextFormatting.t(), color()) :: TextFormatting.t()
  def set_background(style, color) do
    TextFormatting.set_background(style, color)
  end

  @doc """
  Gets the foreground color.
  """
  @spec get_foreground(TextFormatting.t()) :: color()
  def get_foreground(style) do
    TextFormatting.get_foreground(style)
  end

  @doc """
  Gets the background color.
  """
  @spec get_background(TextFormatting.t()) :: color()
  def get_background(style) do
    TextFormatting.get_background(style)
  end

  @doc """
  Sets double-width mode for the current line.
  """
  @spec set_double_width(TextFormatting.t()) :: TextFormatting.t()
  def set_double_width(style) do
    TextFormatting.set_double_width(style)
  end

  @doc """
  Sets double-height top half mode for the current line.
  """
  @spec set_double_height_top(TextFormatting.t()) :: TextFormatting.t()
  def set_double_height_top(style) do
    TextFormatting.set_double_height_top(style)
  end

  @doc """
  Sets double-height bottom half mode for the current line.
  """
  @spec set_double_height_bottom(TextFormatting.t()) :: TextFormatting.t()
  def set_double_height_bottom(style) do
    TextFormatting.set_double_height_bottom(style)
  end

  @doc """
  Resets to single-width, single-height mode.
  """
  @spec reset_size(TextFormatting.t()) :: TextFormatting.t()
  def reset_size(style) do
    TextFormatting.reset_size(style)
  end

  @doc """
  Calculates the effective width of a character based on the current style.
  """
  @spec effective_width(TextFormatting.t(), String.t()) :: non_neg_integer()
  def effective_width(style, char) do
    TextFormatting.effective_width(style, char)
  end

  @doc """
  Gets the hyperlink URI.
  """
  @spec get_hyperlink(TextFormatting.t()) :: String.t() | nil
  def get_hyperlink(style) do
    TextFormatting.get_hyperlink(style)
  end

  @doc """
  Sets a hyperlink URI.
  """
  @spec set_hyperlink(TextFormatting.t(), String.t() | nil) ::
          TextFormatting.t()
  def set_hyperlink(style, url) do
    TextFormatting.set_hyperlink(style, url)
  end

  @doc """
  Converts an ANSI color code to a color name.
  """
  @spec ansi_code_to_color_name(integer()) ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | :bright_black
          | :bright_red
          | :bright_green
          | :bright_yellow
          | :bright_blue
          | :bright_magenta
          | :bright_cyan
          | :bright_white
          | nil
  def ansi_code_to_color_name(code) do
    TextFormatting.ansi_code_to_color_name(code)
  end

  @doc """
  Formats SGR parameters for DECRQSS responses.
  """
  @spec format_sgr_params(TextFormatting.t()) :: String.t()
  def format_sgr_params(style) do
    TextFormatting.format_sgr_params(style)
  end
end
