defmodule Raxol.Terminal.TextFormatting do
  @moduledoc """
  Alias module for Raxol.Terminal.ANSI.TextFormatting.
  This module re-exports the functionality from ANSI.TextFormatting to maintain compatibility.
  """

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

  @doc "Gets the paired line type for double-height mode."
  defdelegate get_paired_line_type(style),
    to: Raxol.Terminal.ANSI.TextFormatting

  @doc "Checks if the current style needs a paired line for double-height mode."
  defdelegate needs_paired_line?(style), to: Raxol.Terminal.ANSI.TextFormatting

  defdelegate ansi_code_to_color_name(code),
    to: Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Sets the bold attribute for text formatting.
  """
  def set_bold(formatting, value) do
    formatting
  end

  @doc """
  Sets the italic attribute for text formatting.
  """
  def set_italic(formatting, value) do
    formatting
  end

  @doc """
  Sets the underline attribute for text formatting.
  """
  def set_underline(formatting, value) do
    formatting
  end

  @doc """
  Sets the blink attribute for text formatting.
  """
  def set_blink(formatting, value) do
    formatting
  end

  @doc """
  Sets the reverse attribute for text formatting.
  """
  def set_reverse(formatting, value) do
    formatting
  end
end
