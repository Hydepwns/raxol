defmodule Raxol.Terminal.Commands.WindowHandlers do
  @moduledoc '''
  Handles window-related commands and operations for the terminal.
  '''

  @doc '''
  Returns the default character width in pixels.
  This is used for calculating window dimensions and text layout.
  '''
  @spec default_char_width_px() :: non_neg_integer()
  def default_char_width_px, do: 8

  @doc '''
  Returns the default character height in pixels.
  '''
  @spec default_char_height_px() :: non_neg_integer()
  def default_char_height_px, do: 16

  @doc '''
  Calculates the window width in characters based on the pixel width.
  '''
  @spec calculate_width_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_width_chars(pixel_width) do
    div(pixel_width, default_char_width_px())
  end

  @doc '''
  Calculates the window height in characters based on the pixel height.
  '''
  @spec calculate_height_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_height_chars(pixel_height) do
    div(pixel_height, default_char_height_px())
  end
end
