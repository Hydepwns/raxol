defmodule Raxol.Terminal.Config.Manager do
  import Raxol.Guards

  @moduledoc """
  Manages terminal configuration including settings, preferences, and environment variables.
  This module is responsible for handling configuration operations and state.
  """

  use GenServer
  alias Raxol.Terminal.{Emulator, Config}
  require Raxol.Core.Runtime.Log

  # Client API

  @doc """
  Starts the config manager.
  """
  @spec start_link() :: GenServer.on_start()
  def start_link do
    start_link([])
  end

  @doc """
  Starts the config manager with options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts,
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    {:ok, new(width, height)}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private functions

  @doc """
  Creates a new config manager.
  """
  @spec new() :: map()
  def new do
    %{
      settings: %{},
      preferences: %{},
      environment: %{}
    }
  end

  @doc """
  Creates a new config manager with width and height.
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: Config.t()
  defp new(width, height) do
    %Config{
      version: 1,
      width: width,
      height: height,
      colors: %{},
      styles: %{},
      input: %{},
      performance: %{},
      mode: %{}
    }
  end

  @doc """
  Gets a configuration setting.
  Returns the setting value or nil.
  """
  @spec get_setting(Emulator.t(), atom()) :: any()
  def get_setting(emulator, setting) when atom?(setting) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)

    case setting do
      :width -> config.width
      :height -> config.height
      :colors -> config.colors
      :styles -> config.styles
      :input -> config.input
      :performance -> config.performance
      :mode -> config.mode
      _ -> nil
    end
  end

  @doc """
  Sets a configuration setting.
  Returns the updated emulator.
  """
  @spec set_setting(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_setting(emulator, setting, value) when atom?(setting) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    updated_config = update_config_setting(config, setting, value)
    %{emulator | config: updated_config}
  end

  defp update_config_setting(config, :width, value)
       when integer?(value) and value > 0 do
    %{config | width: value}
  end

  defp update_config_setting(config, :height, value)
       when integer?(value) and value > 0 do
    %{config | height: value}
  end

  defp update_config_setting(config, :colors, value) when map?(value) do
    %{config | colors: Map.merge(config.colors, value)}
  end

  defp update_config_setting(config, :styles, value) when map?(value) do
    %{config | styles: Map.merge(config.styles, value)}
  end

  defp update_config_setting(config, :input, value) when map?(value) do
    %{config | input: Map.merge(config.input, value)}
  end

  defp update_config_setting(config, :performance, value) when map?(value) do
    %{config | performance: Map.merge(config.performance, value)}
  end

  defp update_config_setting(config, :mode, value) when map?(value) do
    %{config | mode: Map.merge(config.mode, value)}
  end

  defp update_config_setting(config, _setting, _value) do
    config
  end

  @doc """
  Gets a preference value.
  Returns the preference value or nil.
  """
  @spec get_preference(Emulator.t(), atom()) :: any()
  def get_preference(emulator, preference) when atom?(preference) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    get_in(config.mode, [preference])
  end

  @doc """
  Sets a preference value.
  Returns the updated emulator.
  """
  @spec set_preference(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_preference(emulator, preference, value) when atom?(preference) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    mode = Map.put(config.mode, preference, value)
    %{emulator | config: %{config | mode: mode}}
  end

  @doc """
  Gets an environment variable.
  Returns the environment variable value or nil.
  """
  @spec get_environment(Emulator.t(), String.t()) :: String.t() | nil
  def get_environment(emulator, key) when binary?(key) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    get_in(config.input, [key])
  end

  @doc """
  Sets an environment variable.
  Returns the updated emulator.
  """
  @spec set_environment(Emulator.t(), String.t(), String.t()) :: Emulator.t()
  def set_environment(emulator, key, value)
      when binary?(key) and binary?(value) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    input = Map.put(config.input, key, value)
    %{emulator | config: %{config | input: input}}
  end

  @doc """
  Gets all environment variables.
  Returns the map of environment variables.
  """
  @spec get_all_environment(Emulator.t()) :: %{String.t() => String.t()}
  def get_all_environment(emulator) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    config.input
  end

  @doc """
  Sets multiple environment variables.
  Returns the updated emulator.
  """
  @spec set_environment_variables(Emulator.t(), %{String.t() => String.t()}) ::
          Emulator.t()
  def set_environment_variables(emulator, variables) when map?(variables) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    input = Map.merge(config.input, variables)
    %{emulator | config: %{config | input: input}}
  end

  @doc """
  Clears all environment variables.
  Returns the updated emulator.
  """
  @spec clear_environment(Emulator.t()) :: Emulator.t()
  def clear_environment(emulator) do
    config = Raxol.Terminal.Emulator.get_config_struct(emulator)
    %{emulator | config: %{config | input: %{}}}
  end

  @doc """
  Resets the config manager to its initial state.
  Returns the updated emulator.
  """
  @spec reset_config_manager(Emulator.t()) :: Emulator.t()
  def reset_config_manager(emulator) do
    %{emulator | config: new()}
  end
end
