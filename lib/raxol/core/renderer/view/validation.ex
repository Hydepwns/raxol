defmodule Raxol.Core.Renderer.View.Validation do
  @moduledoc """
  Validation functions for the View module.
  Extracted from the main View module to improve maintainability.
  """

  @doc """
  Validates view type and raises an error if invalid.
  """
  def validate_view_type(type) do
    valid_types = [
      :text,
      :box,
      :flex,
      :grid,
      :border,
      :scroll,
      :label,
      :button,
      :checkbox,
      :panel
    ]

    if type not in valid_types do
      raise ArgumentError, "Invalid view type: #{inspect(type)}"
    end
  end

  @doc """
  Validates view options and raises an error if invalid.
  """
  def validate_view_options(opts) do
    validate_size_option(opts)
    validate_position_option(opts)
    validate_container_dimensions(opts)
  end

  @doc """
  Validates layout dimensions and raises an error if invalid.
  """
  def validate_layout_dimensions(dimensions) do
    require Keyword

    if !Keyword.keyword?(dimensions) do
      raise ArgumentError,
            "View.layout macro expects a keyword list as the second argument, got: #{inspect(dimensions)}"
    end

    width = Keyword.get(dimensions, :width)
    height = Keyword.get(dimensions, :height)

    if is_integer(width) and width <= 0 do
      raise ArgumentError, "Container width must be a positive integer"
    end

    if is_integer(height) and height <= 0 do
      raise ArgumentError, "Container height must be a positive integer"
    end
  end

  # Private validation functions

  defp validate_size_option(opts) do
    if Keyword.has_key?(opts, :size) do
      size = Keyword.get(opts, :size)

      if not valid_size?(size) do
        raise ArgumentError, "Size must be a tuple of two positive integers"
      end
    end
  end

  defp validate_position_option(opts) do
    if Keyword.has_key?(opts, :position) do
      position = Keyword.get(opts, :position)

      if not valid_position?(position) do
        raise ArgumentError, "Position must be a tuple of two integers"
      end
    end
  end

  defp validate_container_dimensions(opts) do
    if Keyword.has_key?(opts, :width) or Keyword.has_key?(opts, :height) do
      width = Keyword.get(opts, :width)
      height = Keyword.get(opts, :height)

      if (is_integer(width) and width <= 0) or
           (is_integer(height) and height <= 0) do
        raise ArgumentError, "Container dimensions must be positive integers"
      end
    end
  end

  defp valid_size?({width, height})
       when is_integer(width) and is_integer(height) do
    width > 0 and height > 0
  end

  defp valid_size?(_), do: false

  defp valid_position?({x, y}) when is_integer(x) and is_integer(y), do: true
  defp valid_position?(_), do: false
end
