defmodule Raxol.Terminal.Formatting.Manager do
  @moduledoc """
  Manages text formatting operations for the terminal emulator.
  This module handles text styles, attributes, and formatting state.
  """

  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Creates a new text formatting state.
  """
  @spec new() :: TextFormatting.text_style()
  def new do
    TextFormatting.new()
  end

  @doc """
  Gets the current text style.
  """
  @spec get_style(Raxol.Terminal.Emulator.t()) :: TextFormatting.text_style()
  def get_style(emulator) do
    emulator.style
  end

  @doc """
  Updates the text style.
  """
  @spec update_style(Raxol.Terminal.Emulator.t(), TextFormatting.text_style()) :: Raxol.Terminal.Emulator.t()
  def update_style(emulator, style) do
    %{emulator | style: style}
  end

  @doc """
  Sets a text attribute.
  """
  @spec set_attribute(Raxol.Terminal.Emulator.t(), atom()) :: Raxol.Terminal.Emulator.t()
  def set_attribute(emulator, attribute) do
    new_style = TextFormatting.set_attribute(emulator.style, attribute)
    update_style(emulator, new_style)
  end

  @doc """
  Resets a text attribute.
  """
  @spec reset_attribute(Raxol.Terminal.Emulator.t(), atom()) :: Raxol.Terminal.Emulator.t()
  def reset_attribute(emulator, attribute) do
    new_style = TextFormatting.reset_attribute(emulator.style, attribute)
    update_style(emulator, new_style)
  end

  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(Raxol.Terminal.Emulator.t(), TextFormatting.color()) :: Raxol.Terminal.Emulator.t()
  def set_foreground(emulator, color) do
    new_style = TextFormatting.set_foreground(emulator.style, color)
    update_style(emulator, new_style)
  end

  @doc """
  Sets the background color.
  """
  @spec set_background(Raxol.Terminal.Emulator.t(), TextFormatting.color()) :: Raxol.Terminal.Emulator.t()
  def set_background(emulator, color) do
    new_style = TextFormatting.set_background(emulator.style, color)
    update_style(emulator, new_style)
  end

  @doc """
  Resets all text attributes.
  """
  @spec reset_all_attributes(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Emulator.t()
  def reset_all_attributes(emulator) do
    new_style = TextFormatting.reset_all(emulator.style)
    update_style(emulator, new_style)
  end

  @doc """
  Gets the current foreground color.
  """
  @spec get_foreground(Raxol.Terminal.Emulator.t()) :: TextFormatting.color()
  def get_foreground(emulator) do
    TextFormatting.get_foreground(emulator.style)
  end

  @doc """
  Gets the current background color.
  """
  @spec get_background(Raxol.Terminal.Emulator.t()) :: TextFormatting.color()
  def get_background(emulator) do
    TextFormatting.get_background(emulator.style)
  end

  @doc """
  Checks if an attribute is set.
  """
  @spec attribute_set?(Raxol.Terminal.Emulator.t(), atom()) :: boolean()
  def attribute_set?(emulator, attribute) do
    TextFormatting.attribute_set?(emulator.style, attribute)
  end

  @doc """
  Gets all set attributes.
  """
  @spec get_set_attributes(Raxol.Terminal.Emulator.t()) :: list(atom())
  def get_set_attributes(emulator) do
    TextFormatting.get_set_attributes(emulator.style)
  end
end
