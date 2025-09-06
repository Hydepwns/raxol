defmodule Raxol.Terminal.Commands.WindowHandlersCached do
  @moduledoc """
  Cached version of window handlers using font metrics cache.

  This module provides the same interface as WindowHandlers but uses
  cached font metrics for improved performance. All font dimension
  calculations are cached to avoid repeated computation.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Font.Manager, as: FontManager
  alias Raxol.Core.Performance.Caches.FontMetricsCache

  # Default font configuration matching WindowHandlers
  @default_font_size 14
  # Results in 16px height for 14pt font
  @default_line_height 1.143

  @spec default_char_width_px() :: non_neg_integer()
  def default_char_width_px do
    font_manager = get_default_font_manager()
    {char_width, _} = FontMetricsCache.get_font_dimensions(font_manager)
    char_width
  end

  @spec default_char_height_px() :: non_neg_integer()
  def default_char_height_px do
    font_manager = get_default_font_manager()
    {_, char_height} = FontMetricsCache.get_font_dimensions(font_manager)
    char_height
  end

  @spec calculate_width_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_width_chars(pixel_width) do
    font_manager = get_default_font_manager()
    FontMetricsCache.chars_in_width(font_manager, pixel_width)
  end

  @spec calculate_height_chars(non_neg_integer()) :: non_neg_integer()
  def calculate_height_chars(pixel_height) do
    font_manager = get_default_font_manager()
    FontMetricsCache.lines_in_height(font_manager, pixel_height)
  end

  @spec calculate_pixel_width(non_neg_integer()) :: non_neg_integer()
  def calculate_pixel_width(char_count) do
    font_manager = get_default_font_manager()
    FontMetricsCache.calculate_pixel_width(font_manager, char_count)
  end

  @spec calculate_pixel_height(non_neg_integer()) :: non_neg_integer()
  def calculate_pixel_height(line_count) do
    font_manager = get_default_font_manager()
    FontMetricsCache.calculate_pixel_height(font_manager, line_count)
  end

  @doc """
  Calculate dimensions with custom font configuration.
  """
  @spec calculate_with_font(
          FontManager.t(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          %{chars: non_neg_integer(), lines: non_neg_integer()}
  def calculate_with_font(
        %FontManager{} = font_manager,
        pixel_width,
        pixel_height
      ) do
    chars = FontMetricsCache.chars_in_width(font_manager, pixel_width)
    lines = FontMetricsCache.lines_in_height(font_manager, pixel_height)
    %{chars: chars, lines: lines}
  end

  @doc """
  Get string width in pixels using cached metrics.
  """
  @spec get_string_pixel_width(String.t()) :: non_neg_integer()
  def get_string_pixel_width(string) do
    char_width = FontMetricsCache.get_string_width(string)
    font_manager = get_default_font_manager()
    {char_width_px, _} = FontMetricsCache.get_font_dimensions(font_manager)
    char_width * char_width_px
  end

  @doc """
  Get character width in pixels using cached metrics.
  """
  @spec get_char_pixel_width(String.t() | integer()) :: non_neg_integer()
  def get_char_pixel_width(char) do
    char_width = FontMetricsCache.get_char_width(char)
    font_manager = get_default_font_manager()
    {char_width_px, _} = FontMetricsCache.get_font_dimensions(font_manager)
    char_width * char_width_px
  end

  @spec handle_t(Emulator.t(), list()) ::
          {:ok, Emulator.t()} | {:error, atom(), Emulator.t()}
  def handle_t(emulator, params) do
    # Delegate to original WindowHandlers for non-metric operations
    Raxol.Terminal.Commands.WindowHandlers.handle_t(emulator, params)
  end

  # Private functions

  defp get_default_font_manager do
    # Create a font manager with default settings
    # This could be made configurable or retrieved from application config
    %FontManager{
      family: "monospace",
      size: @default_font_size,
      weight: :normal,
      style: :normal,
      line_height: @default_line_height,
      letter_spacing: 0,
      fallback_fonts: ["monospace"],
      custom_fonts: %{}
    }
  end
end
