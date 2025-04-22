defmodule Raxol.Terminal.TextFormatting do
  @moduledoc """
  Alias module for Raxol.Terminal.ANSI.TextFormatting.
  This module re-exports the functionality from ANSI.TextFormatting to maintain compatibility.
  """

  # Re-export all functions from the ANSI.TextFormatting module
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

  defdelegate needs_paired_line?(style), to: Raxol.Terminal.ANSI.TextFormatting
  defdelegate paired_line_type(style), to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate ansi_code_to_color_name(code),
    to: Raxol.Terminal.ANSI.TextFormatting
end
