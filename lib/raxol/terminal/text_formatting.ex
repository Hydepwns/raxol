defmodule Raxol.Terminal.TextFormatting do
  @moduledoc '''
  Alias module for Raxol.Terminal.ANSI.TextFormatting.
  This module re-exports the functionality from ANSI.TextFormatting to maintain compatibility.
  '''

  defdelegate new(), to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate set_foreground(style, color),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate set_background(style, color),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate get_foreground(style), to: Raxol.Terminal.ANSI.TextFormatting
  defdelegate get_background(style), to: Raxol.Terminal.ANSI.TextFormatting
  defdelegate set_double_width(style), to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate set_double_height_top(style),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate set_double_height_bottom(style),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate reset_size(style), to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate apply_attribute(style, attribute),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate apply_color(style, type, color),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate effective_width(style, char),
    to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate get_default_style(),
    to: Raxol.Terminal.ANSI.TextFormatting,
    as: :new

  @doc 'Gets the paired line type for double-height mode.'
  defdelegate get_paired_line_type(style),
    to: Raxol.Terminal.ANSI.TextFormatting

  @doc 'Checks if the current style needs a paired line for double-height mode.'
  defdelegate needs_paired_line?(style), to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate ansi_code_to_color_name(code),
    to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the bold attribute for text formatting.
  '''
  defdelegate set_bold(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the italic attribute for text formatting.
  '''
  defdelegate set_italic(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the underline attribute for text formatting.
  '''
  defdelegate set_underline(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the blink attribute for text formatting.
  '''
  defdelegate set_blink(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the reverse attribute for text formatting.
  '''
  defdelegate set_reverse(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the faint attribute for text formatting.
  '''
  defdelegate set_faint(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the conceal attribute for text formatting.
  '''
  defdelegate set_conceal(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the strikethrough attribute for text formatting.
  '''
  defdelegate set_strikethrough(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the fraktur attribute for text formatting.
  '''
  defdelegate set_fraktur(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the double underline attribute for text formatting.
  '''
  defdelegate set_double_underline(style),
    to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the framed attribute for text formatting.
  '''
  defdelegate set_framed(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the encircled attribute for text formatting.
  '''
  defdelegate set_encircled(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Sets the overlined attribute for text formatting.
  '''
  defdelegate set_overlined(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Resets the bold attribute for text formatting.
  '''
  defdelegate reset_bold(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Resets the italic attribute for text formatting.
  '''
  defdelegate reset_italic(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Resets the underline attribute for text formatting.
  '''
  defdelegate reset_underline(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Resets the blink attribute for text formatting.
  '''
  defdelegate reset_blink(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Resets the reverse attribute for text formatting.
  '''
  defdelegate reset_reverse(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Gets the hyperlink from a style.
  '''
  defdelegate get_hyperlink(style), to: Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Formats a style into SGR parameters.
  '''
  defdelegate format_sgr_params(style), to: Raxol.Terminal.ANSI.TextFormatting
end
