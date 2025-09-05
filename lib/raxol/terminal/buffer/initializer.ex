defmodule Raxol.Terminal.Buffer.Initializer do
  @moduledoc """
  Handles initialization and validation of screen buffers.
  This module provides functions for creating new screen buffers and validating
  their dimensions and properties.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc """
  Creates a new screen buffer with the specified dimensions.
  Validates and normalizes the input dimensions to ensure they are valid.
  """
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def new(width, height, scrollback_limit \\ 1000) do
    width = validate_dimension(width, 80)
    height = validate_dimension(height, 24)
    scrollback_limit = validate_dimension(scrollback_limit, 1000)

    buffer = %ScreenBuffer{
      cells: create_empty_grid(width, height),
      scrollback: [],
      scrollback_limit: scrollback_limit,
      selection: nil,
      scroll_region: nil,
      scroll_position: 0,
      width: width,
      height: height,
      default_style: TextFormatting.new()
    }

    buffer
  end

  @doc """
  Validates a dimension value, returning a default if invalid.
  """
  @spec validate_dimension(integer(), non_neg_integer()) :: non_neg_integer()
  def validate_dimension(dimension, _default)
      when is_integer(dimension) and dimension > 0 do
    dimension
  end

  def validate_dimension(_, default), do: default

  @spec create_empty_grid(non_neg_integer(), non_neg_integer()) ::
          list(list(Cell.t()))
  defp create_empty_grid(width, height) do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new()
      end
    end
  end
end
