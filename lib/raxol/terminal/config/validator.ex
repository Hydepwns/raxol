defmodule Raxol.Terminal.Config.Validator do
  @moduledoc """
  Validates terminal configuration settings.
  """

  alias Raxol.Terminal.Config

  @type validation_result :: :ok | {:error, String.t()}

  @doc """
  Validates a configuration update.
  """
  @spec validate_update(Config.t(), map()) :: validation_result()
  def validate_update(config, updates) when is_map(updates) do
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
    with :ok <- validate_dimensions(%{width: config.width, height: config.height}),
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
       when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    :ok
  end

  defp validate_dimensions(%{width: width, height: height}) do
    {:error, "Invalid dimensions: width=#{width}, height=#{height}"}
  end

  defp validate_dimensions(_), do: :ok

  defp validate_colors(%{colors: colors}) when is_map(colors) do
    validate_color_map(colors)
  end

  defp validate_colors(_), do: :ok

  defp validate_color_map(colors) do
    Enum.reduce_while(colors, :ok, fn {key, value}, :ok ->
      case validate_color_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_color_value({r, g, b})
       when is_integer(r) and is_integer(g) and is_integer(b) and
              r >= 0 and r <= 255 and
              g >= 0 and g <= 255 and
              b >= 0 and b <= 255 do
    :ok
  end

  defp validate_color_value(value) do
    {:error, "Invalid color value: #{inspect(value)}"}
  end

  defp validate_styles(%{styles: styles}) when is_map(styles) do
    validate_style_map(styles)
  end

  defp validate_styles(_), do: :ok

  defp validate_style_map(styles) do
    Enum.reduce_while(styles, :ok, fn {key, value}, :ok ->
      case validate_style_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_style_value(value) when is_boolean(value), do: :ok
  defp validate_style_value(value) when is_atom(value), do: :ok
  defp validate_style_value(value), do: {:error, "Invalid style value: #{inspect(value)}"}

  defp validate_input(%{input: input}) when is_map(input) do
    validate_input_map(input)
  end

  defp validate_input(_), do: :ok

  defp validate_input_map(input) do
    Enum.reduce_while(input, :ok, fn {key, value}, :ok ->
      case validate_input_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_input_value(value) when is_boolean(value), do: :ok
  defp validate_input_value(value) when is_atom(value), do: :ok
  defp validate_input_value(value), do: {:error, "Invalid input value: #{inspect(value)}"}

  defp validate_performance(%{performance: perf}) when is_map(perf) do
    validate_performance_map(perf)
  end

  defp validate_performance(_), do: :ok

  defp validate_performance_map(perf) do
    Enum.reduce_while(perf, :ok, fn {key, value}, :ok ->
      case validate_performance_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_performance_value(value) when is_integer(value) and value > 0, do: :ok
  defp validate_performance_value(value) when is_boolean(value), do: :ok
  defp validate_performance_value(value), do: {:error, "Invalid performance value: #{inspect(value)}"}

  defp validate_mode(%{mode: mode}) when is_map(mode) do
    validate_mode_map(mode)
  end

  defp validate_mode(_), do: :ok

  defp validate_mode_map(mode) do
    Enum.reduce_while(mode, :ok, fn {key, value}, :ok ->
      case validate_mode_value(value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_mode_value(value) when is_boolean(value), do: :ok
  defp validate_mode_value(value) when is_atom(value), do: :ok
  defp validate_mode_value(value), do: {:error, "Invalid mode value: #{inspect(value)}"}
end
