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

    validate_type_membership(type in valid_types, type)
  end

  defp validate_type_membership(true, _type), do: :ok

  defp validate_type_membership(false, type) do
    raise ArgumentError, "Invalid view type: #{inspect(type)}"
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

    validate_keyword_list(Keyword.keyword?(dimensions), dimensions)

    width = Keyword.get(dimensions, :width)
    height = Keyword.get(dimensions, :height)

    validate_width_dimension(width)
    validate_height_dimension(height)
  end

  defp validate_keyword_list(true, _dimensions), do: :ok

  defp validate_keyword_list(false, dimensions) do
    raise ArgumentError,
          "View.layout macro expects a keyword list as the second argument, got: #{inspect(dimensions)}"
  end

  defp validate_width_dimension(width) when is_integer(width) and width <= 0 do
    raise ArgumentError, "Container width must be a positive integer"
  end

  defp validate_width_dimension(_width), do: :ok

  defp validate_height_dimension(height)
       when is_integer(height) and height <= 0 do
    raise ArgumentError, "Container height must be a positive integer"
  end

  defp validate_height_dimension(_height), do: :ok

  # Private validation functions

  defp validate_size_option(opts) do
    handle_size_validation(Keyword.has_key?(opts, :size), opts)
  end

  defp handle_size_validation(false, _opts), do: :ok

  defp handle_size_validation(true, opts) do
    size = Keyword.get(opts, :size)
    validate_size_value(valid_size?(size), size)
  end

  defp validate_size_value(true, _size), do: :ok

  defp validate_size_value(false, _size) do
    raise ArgumentError, "Size must be a tuple of two positive integers"
  end

  defp validate_position_option(opts) do
    handle_position_validation(Keyword.has_key?(opts, :position), opts)
  end

  defp handle_position_validation(false, _opts), do: :ok

  defp handle_position_validation(true, opts) do
    position = Keyword.get(opts, :position)
    validate_position_value(valid_position?(position), position)
  end

  defp validate_position_value(true, _position), do: :ok

  defp validate_position_value(false, _position) do
    raise ArgumentError, "Position must be a tuple of two integers"
  end

  defp validate_container_dimensions(opts) do
    has_dimensions =
      Keyword.has_key?(opts, :width) or Keyword.has_key?(opts, :height)

    handle_container_dimension_validation(has_dimensions, opts)
  end

  defp handle_container_dimension_validation(false, _opts), do: :ok

  defp handle_container_dimension_validation(true, opts) do
    width = Keyword.get(opts, :width)
    height = Keyword.get(opts, :height)

    invalid_dimensions =
      (is_integer(width) and width <= 0) or (is_integer(height) and height <= 0)

    validate_container_dimension_values(invalid_dimensions)
  end

  defp validate_container_dimension_values(false), do: :ok

  defp validate_container_dimension_values(true) do
    raise ArgumentError, "Container dimensions must be positive integers"
  end

  defp valid_size?({width, height})
       when is_integer(width) and is_integer(height) do
    width > 0 and height > 0
  end

  defp valid_size?(_), do: false

  defp valid_position?({x, y}) when is_integer(x) and is_integer(y), do: true
  defp valid_position?(_), do: false
end
