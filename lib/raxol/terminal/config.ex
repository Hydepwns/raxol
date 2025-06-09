defmodule Raxol.Terminal.Config do
  @moduledoc """
  Handles terminal settings and behavior, including:
  - Terminal dimensions
  - Color settings
  - Input handling
  - Terminal state management
  """

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          colors: map(),
          styles: map(),
          input: map(),
          performance: map(),
          mode: map()
        }

  defstruct width: 80,
            height: 24,
            colors: %{},
            styles: %{},
            input: %{},
            performance: %{},
            mode: %{}

  @doc """
  Creates a new terminal configuration with default values.

  ## Returns

  A new `t:Raxol.Terminal.Config.t/0` struct with default values.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new terminal configuration with custom dimensions.

  ## Parameters

  * `width` - The terminal width in characters
  * `height` - The terminal height in characters

  ## Returns

  A new `t:Raxol.Terminal.Config.t/0` struct with the specified dimensions.
  """
  @spec new(integer(), integer()) :: t()
  def new(width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    %__MODULE__{width: width, height: height}
  end

  @doc """
  Updates the terminal dimensions.

  ## Parameters

  * `config` - The current configuration
  * `width` - The new terminal width
  * `height` - The new terminal height

  ## Returns

  The updated configuration with new dimensions.
  """
  @spec set_dimensions(t(), integer(), integer()) :: t()
  def set_dimensions(config, width, height)
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 do
    %{config | width: width, height: height}
  end

  @doc """
  Gets the current terminal dimensions.

  ## Parameters

  * `config` - The current configuration

  ## Returns

  A tuple `{width, height}` with the current dimensions.
  """
  @spec get_dimensions(t()) :: {integer(), integer()}
  def get_dimensions(config) do
    {config.width, config.height}
  end

  @doc """
  Updates the color settings.

  ## Parameters

  * `config` - The current configuration
  * `colors` - A map of color settings to update

  ## Returns

  The updated configuration with new color settings.
  """
  @spec set_colors(t(), map()) :: t()
  def set_colors(config, colors) when is_map(colors) do
    %{config | colors: Map.merge(config.colors, colors)}
  end

  @doc """
  Gets the current color settings.

  ## Parameters

  * `config` - The current configuration

  ## Returns

  A map containing the current color settings.
  """
  @spec get_colors(t()) :: map()
  def get_colors(config) do
    config.colors
  end

  @doc """
  Updates the style settings.

  ## Parameters

  * `config` - The current configuration
  * `styles` - A map of style settings to update

  ## Returns

  The updated configuration with new style settings.
  """
  @spec set_styles(t(), map()) :: t()
  def set_styles(config, styles) when is_map(styles) do
    %{config | styles: Map.merge(config.styles, styles)}
  end

  @doc """
  Gets the current style settings.

  ## Parameters

  * `config` - The current configuration

  ## Returns

  A map containing the current style settings.
  """
  @spec get_styles(t()) :: map()
  def get_styles(config) do
    config.styles
  end

  @doc """
  Updates the input handling settings.

  ## Parameters

  * `config` - The current configuration
  * `input` - A map of input settings to update

  ## Returns

  The updated configuration with new input settings.
  """
  @spec set_input(t(), map()) :: t()
  def set_input(config, input) when is_map(input) do
    %{config | input: Map.merge(config.input, input)}
  end

  @doc """
  Gets the current input handling settings.

  ## Parameters

  * `config` - The current configuration

  ## Returns

  A map containing the current input settings.
  """
  @spec get_input(t()) :: map()
  def get_input(config) do
    config.input
  end

  @doc """
  Updates the performance settings.

  ## Parameters

  * `config` - The current configuration
  * `performance` - A map of performance settings to update

  ## Returns

  The updated configuration with new performance settings.
  """
  @spec set_performance(t(), map()) :: t()
  def set_performance(config, performance) when is_map(performance) do
    %{config | performance: Map.merge(config.performance, performance)}
  end

  @doc """
  Gets the current performance settings.

  ## Parameters

  * `config` - The current configuration

  ## Returns

  A map containing the current performance settings.
  """
  @spec get_performance(t()) :: map()
  def get_performance(config) do
    config.performance
  end

  @doc """
  Updates the terminal mode settings.

  ## Parameters

  * `config` - The current configuration
  * `mode` - A map of mode settings to update

  ## Returns

  The updated configuration with new mode settings.
  """
  @spec set_mode(t(), map()) :: t()
  def set_mode(config, mode) when is_map(mode) do
    %{config | mode: Map.merge(config.mode, mode)}
  end

  @doc """
  Gets the current terminal mode settings.

  ## Parameters

  * `config` - The current configuration

  ## Returns

  A map containing the current mode settings.
  """
  @spec get_mode(t()) :: map()
  def get_mode(config) do
    config.mode
  end

  @doc """
  Merges a map of options with the current configuration.
  Validates the options before merging.

  ## Parameters

  * `config` - The current configuration
  * `opts` - A map of options to merge

  ## Returns

  The updated configuration with merged options.
  """
  def merge_opts(config, opts) when is_map(opts) do
    # Validate options before merging
    case validate_config(opts) do
      :ok ->
        do_merge_opts(config, opts)

      {:error, reason} ->
        raise ArgumentError, "Invalid config options: #{inspect(reason)}"
    end
  end

  @doc """
  Validates a configuration map.
  Checks for required fields and valid values.

  ## Parameters

  * `config` - The configuration to validate

  ## Returns

  `:ok` if the configuration is valid, `{:error, reason}` otherwise.
  """
  def validate_config(config) when is_map(config) do
    with :ok <- validate_dimensions(config),
         :ok <- validate_colors(config),
         :ok <- validate_styles(config),
         :ok <- validate_input(config),
         :ok <- validate_performance(config),
         :ok <- validate_mode(config) do
      :ok
    end
  end

  # Private helpers

  defp do_merge_opts(config, opts) do
    config
    |> maybe_merge(:width, opts)
    |> maybe_merge(:height, opts)
    |> maybe_merge(:colors, opts)
    |> maybe_merge(:styles, opts)
    |> maybe_merge(:input, opts)
    |> maybe_merge(:performance, opts)
    |> maybe_merge(:mode, opts)
  end

  defp maybe_merge(config, key, opts) do
    case Map.get(opts, key) do
      nil -> config
      value -> Map.put(config, key, value)
    end
  end

  defp validate_dimensions(config) do
    case {Map.get(config, :width), Map.get(config, :height)} do
      {nil, nil} ->
        :ok

      {width, height}
      when is_integer(width) and is_integer(height) and width > 0 and height > 0 ->
        :ok

      _ ->
        {:error, :invalid_dimensions}
    end
  end

  defp validate_colors(config) do
    case Map.get(config, :colors) do
      nil -> :ok
      colors when is_map(colors) -> :ok
      _ -> {:error, :invalid_colors}
    end
  end

  defp validate_styles(config) do
    case Map.get(config, :styles) do
      nil -> :ok
      styles when is_map(styles) -> :ok
      _ -> {:error, :invalid_styles}
    end
  end

  defp validate_input(config) do
    case Map.get(config, :input) do
      nil -> :ok
      input when is_map(input) -> :ok
      _ -> {:error, :invalid_input}
    end
  end

  defp validate_performance(config) do
    case Map.get(config, :performance) do
      nil -> :ok
      performance when is_map(performance) -> :ok
      _ -> {:error, :invalid_performance}
    end
  end

  defp validate_mode(config) do
    case Map.get(config, :mode) do
      nil -> :ok
      mode when is_map(mode) -> :ok
      _ -> {:error, :invalid_mode}
    end
  end
end
