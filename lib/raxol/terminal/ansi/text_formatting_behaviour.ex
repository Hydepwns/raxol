defmodule Raxol.Terminal.ANSI.TextFormattingBehaviour do
  @moduledoc """
  Defines the behaviour for text formatting in the terminal.
  This includes handling text attributes, colors, and special text modes.
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
          framed: boolean(),
          encircled: boolean(),
          overlined: boolean(),
          foreground: color(),
          background: color(),
          hyperlink: String.t() | nil
        }

  @callback new() :: text_style()
  @callback set_foreground(text_style(), color()) :: text_style()
  @callback set_background(text_style(), color()) :: text_style()
  @callback get_foreground(text_style()) :: color()
  @callback get_background(text_style()) :: color()
  @callback set_double_width(text_style()) :: text_style()
  @callback set_double_height_top(text_style()) :: text_style()
  @callback set_double_height_bottom(text_style()) :: text_style()
  @callback reset_size(text_style()) :: text_style()
  @callback apply_attribute(text_style(), atom()) :: text_style()
  @callback set_bold(text_style()) :: text_style()
  @callback set_faint(text_style()) :: text_style()
  @callback set_italic(text_style()) :: text_style()
  @callback set_underline(text_style()) :: text_style()
  @callback set_blink(text_style()) :: text_style()
  @callback set_reverse(text_style()) :: text_style()
  @callback set_conceal(text_style()) :: text_style()
  @callback set_strikethrough(text_style()) :: text_style()
  @callback set_fraktur(text_style()) :: text_style()
  @callback set_double_underline(text_style()) :: text_style()
  @callback set_framed(text_style()) :: text_style()
  @callback set_encircled(text_style()) :: text_style()
  @callback set_overlined(text_style()) :: text_style()
  @callback set_hyperlink(text_style(), String.t() | nil) :: text_style()
  @callback reset_attributes(text_style()) :: text_style()
  @callback set_attributes(text_style(), list(atom())) :: text_style()
  @callback set_custom(text_style(), atom(), any()) :: text_style()
  @callback update_attrs(text_style(), map()) :: text_style()
  @callback validate(text_style()) :: {:ok, text_style()} | {:error, String.t()}
  @callback reset_bold(text_style()) :: text_style()
  @callback reset_italic(text_style()) :: text_style()
  @callback reset_underline(text_style()) :: text_style()
  @callback reset_blink(text_style()) :: text_style()
  @callback reset_reverse(text_style()) :: text_style()
  @callback reset_framed_encircled(text_style()) :: text_style()
  @callback reset_overlined(text_style()) :: text_style()
end
