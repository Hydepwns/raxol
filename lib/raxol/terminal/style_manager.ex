defmodule Raxol.Terminal.StyleManager do
  @moduledoc """
  Manages terminal style operations including colors, attributes, and formatting.
  This module is responsible for handling all style-related operations in the terminal.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.StyleBuffer
  require Raxol.Core.Runtime.Log

  @doc """
  Gets the style buffer instance.
  Returns the style buffer.
  """
  @spec get_buffer(Emulator.t()) :: StyleBuffer.t()
  def get_buffer(emulator) do
    emulator.style_buffer
  end

  @doc """
  Updates the style buffer instance.
  Returns the updated emulator.
  """
  @spec update_buffer(Emulator.t(), StyleBuffer.t()) :: Emulator.t()
  def update_buffer(emulator, buffer) do
    %{emulator | style_buffer: buffer}
  end

  @doc """
  Sets the foreground color.
  Returns the updated emulator.
  """
  @spec set_foreground(Emulator.t(), String.t()) :: Emulator.t()
  def set_foreground(emulator, color) do
    buffer = StyleBuffer.set_foreground(emulator.style_buffer, color)
    update_buffer(emulator, buffer)
  end

  @doc """
  Sets the background color.
  Returns the updated emulator.
  """
  @spec set_background(Emulator.t(), String.t()) :: Emulator.t()
  def set_background(emulator, color) do
    buffer = StyleBuffer.set_background(emulator.style_buffer, color)
    update_buffer(emulator, buffer)
  end

  @doc """
  Sets text attributes.
  Returns the updated emulator.
  """
  @spec set_attributes(Emulator.t(), list(atom())) :: Emulator.t()
  def set_attributes(emulator, attributes) do
    buffer = StyleBuffer.set_attributes(emulator.style_buffer, attributes)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the current style.
  Returns the current style map.
  """
  @spec get_style(Emulator.t()) :: map()
  def get_style(emulator) do
    StyleBuffer.get_style(emulator.style_buffer)
  end

  @doc """
  Resets the style to default.
  Returns the updated emulator.
  """
  @spec reset_style(Emulator.t()) :: Emulator.t()
  def reset_style(emulator) do
    buffer = StyleBuffer.reset_style(emulator.style_buffer)
    update_buffer(emulator, buffer)
  end

  @doc """
  Applies a style to a region.
  Returns the updated emulator.
  """
  @spec apply_style_to_region(Emulator.t(), {integer(), integer()}, {integer(), integer()}, map()) :: Emulator.t()
  def apply_style_to_region(emulator, start, end_, style) do
    buffer = StyleBuffer.apply_style_to_region(emulator.style_buffer, start, end_, style)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the style at a specific position.
  Returns the style map at that position.
  """
  @spec get_style_at(Emulator.t(), integer(), integer()) :: map()
  def get_style_at(emulator, x, y) do
    StyleBuffer.get_style_at(emulator.style_buffer, x, y)
  end

  @doc """
  Sets the default style.
  Returns the updated emulator.
  """
  @spec set_default_style(Emulator.t(), map()) :: Emulator.t()
  def set_default_style(emulator, style) do
    buffer = StyleBuffer.set_default_style(emulator.style_buffer, style)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the default style.
  Returns the default style map.
  """
  @spec get_default_style(Emulator.t()) :: map()
  def get_default_style(emulator) do
    StyleBuffer.get_default_style(emulator.style_buffer)
  end

  @doc """
  Merges two styles.
  Returns the merged style map.
  """
  @spec merge_styles(map(), map()) :: map()
  def merge_styles(style1, style2) do
    StyleBuffer.merge_styles(style1, style2)
  end

  @doc """
  Validates a style map.
  Returns :ok or {:error, reason}.
  """
  @spec validate_style(map()) :: :ok | {:error, String.t()}
  def validate_style(style) do
    StyleBuffer.validate_style(style)
  end
end
