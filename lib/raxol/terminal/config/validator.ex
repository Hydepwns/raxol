defmodule Raxol.Terminal.Config.Validator do
  import Raxol.Guards

  @moduledoc """
  Validates terminal configuration settings.
  """

  alias Raxol.Terminal.Config

  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Validates a configuration update.
  """
  @spec validate_update(Config.t(), map()) :: validation_result()
  def validate_update(_config, updates) when map?(updates) do
    with :ok <- validate_dimensions(updates),
         :ok <- validate_colors(updates),
         :ok <- validate_styles(updates),
         :ok <- validate_input(updates),
         :ok <- validate_performance(updates),
         :ok <- validate_mode(updates) do
      :ok
    end
  end

  @doc """
  Validates a complete configuration.
  """
  @spec validate_config(Config.t()) :: validation_result()
  def validate_config(%Config{} = config) do
    with :ok <-
           validate_dimensions(%{width: config.width, height: config.height}),
         :ok <- validate_colors(config.colors),
         :ok <- validate_styles(config.styles),
         :ok <- validate_input(config.input),
         :ok <- validate_performance(config.performance),
         :ok <- validate_mode(config.mode) do
      :ok
    end
  end

  # Private validation functions

  defp validate_dimensions(%{width: width, height: height})
       when integer?(width) and integer?(height) and width > 0 and
              height > 0 do
    :ok
  end

  defp validate_dimensions(%{width: width, height: height}) do
    # Handle cases where width or height might be nil or empty
    width_str = if is_nil(width), do: "", else: to_string(width)
    height_str = if is_nil(height), do: "", else: to_string(height)
    {:error, "Invalid dimensions: width=#{width_str}, height=#{height_str}"}
  end

  defp validate_dimensions(_), do: :ok

  defp validate_colors(%{colors: colors}) when map?(colors) do
    validate_color_map(colors)
  end

  defp validate_colors(_), do: :ok

  defp validate_color_map(colors) do
    Enum.reduce_while(colors, :ok, fn {_key, value}, :ok ->
      case validate_color_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_color_value({r, g, b})
       when integer?(r) and integer?(g) and integer?(b) and
              r >= 0 and r <= 255 and
              g >= 0 and g <= 255 and
              b >= 0 and b <= 255 do
    :ok
  end

  defp validate_color_value(value) do
    {:error, "Invalid color value: #{inspect(value)}"}
  end

  defp validate_styles(%{styles: styles}) when map?(styles) do
    validate_style_map(styles)
  end

  defp validate_styles(_), do: :ok

  defp validate_style_map(styles) do
    Enum.reduce_while(styles, :ok, fn {_key, value}, :ok ->
      case validate_style_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_style_value(value) when boolean?(value), do: :ok
  defp validate_style_value(value) when atom?(value), do: :ok

  defp validate_style_value(value),
    do: {:error, "Invalid style value: #{inspect(value)}"}

  defp validate_input(%{input: input}) when map?(input) do
    validate_input_map(input)
  end

  defp validate_input(_), do: :ok

  defp validate_input_map(input) do
    Enum.reduce_while(input, :ok, fn {_key, value}, :ok ->
      case validate_input_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_input_value(value) when boolean?(value), do: :ok
  defp validate_input_value(value) when atom?(value), do: :ok

  defp validate_input_value(value),
    do: {:error, "Invalid input value: #{inspect(value)}"}

  defp validate_performance(%{performance: perf}) when map?(perf) do
    validate_performance_map(perf)
  end

  defp validate_performance(_), do: :ok

  defp validate_performance_map(perf) do
    Enum.reduce_while(perf, :ok, fn {_key, value}, :ok ->
      case validate_performance_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_performance_value(value) when integer?(value) and value > 0,
    do: :ok

  defp validate_performance_value(value) when boolean?(value), do: :ok

  defp validate_performance_value(value),
    do: {:error, "Invalid performance value: #{inspect(value)}"}

  defp validate_mode(%{mode: mode}) when map?(mode) do
    validate_mode_map(mode)
  end

  defp validate_mode(_), do: :ok

  defp validate_mode_map(mode) do
    Enum.reduce_while(mode, :ok, fn {_key, value}, :ok ->
      case validate_mode_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_mode_value(value) when boolean?(value), do: :ok
  defp validate_mode_value(value) when atom?(value), do: :ok

  defp validate_mode_value(value),
    do: {:error, "Invalid mode value: #{inspect(value)}"}
end
