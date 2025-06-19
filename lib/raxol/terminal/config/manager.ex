defmodule Raxol.Terminal.Config.Manager do
  @moduledoc """
  Manages terminal configuration including settings, preferences, and environment variables.
  This module is responsible for handling configuration operations and state.
  """

  alias Raxol.Terminal.{Emulator, Config}
  require Raxol.Core.Runtime.Log

  @doc """
  Creates a new config manager.
  """
  @spec new() :: Config.t()
  def new do
    %Config{
      version: 1,
      width: 80,
      height: 24,
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
  def get_setting(emulator, setting) when is_atom(setting) do
    case setting do
      :width -> emulator.config.width
      :height -> emulator.config.height
      :colors -> emulator.config.colors
      :styles -> emulator.config.styles
      :input -> emulator.config.input
      :performance -> emulator.config.performance
      :mode -> emulator.config.mode
      _ -> nil
    end
  end

  @doc """
  Sets a configuration setting.
  Returns the updated emulator.
  """
  @spec set_setting(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_setting(emulator, setting, value) when is_atom(setting) do
    config = case setting do
      :width when is_integer(value) and value > 0 ->
        %{emulator.config | width: value}
      :height when is_integer(value) and value > 0 ->
        %{emulator.config | height: value}
      :colors when is_map(value) ->
        %{emulator.config | colors: Map.merge(emulator.config.colors, value)}
      :styles when is_map(value) ->
        %{emulator.config | styles: Map.merge(emulator.config.styles, value)}
      :input when is_map(value) ->
        %{emulator.config | input: Map.merge(emulator.config.input, value)}
      :performance when is_map(value) ->
        %{emulator.config | performance: Map.merge(emulator.config.performance, value)}
      :mode when is_map(value) ->
        %{emulator.config | mode: Map.merge(emulator.config.mode, value)}
      _ ->
        emulator.config
    end
    %{emulator | config: config}
  end

  @doc """
  Gets a preference value.
  Returns the preference value or nil.
  """
  @spec get_preference(Emulator.t(), atom()) :: any()
  def get_preference(emulator, preference) when is_atom(preference) do
    get_in(emulator.config.mode, [preference])
  end

  @doc """
  Sets a preference value.
  Returns the updated emulator.
  """
  @spec set_preference(Emulator.t(), atom(), any()) :: Emulator.t()
  def set_preference(emulator, preference, value) when is_atom(preference) do
    mode = Map.put(emulator.config.mode, preference, value)
    %{emulator | config: %{emulator.config | mode: mode}}
  end

  @doc """
  Gets an environment variable.
  Returns the environment variable value or nil.
  """
  @spec get_environment(Emulator.t(), String.t()) :: String.t() | nil
  def get_environment(emulator, key) when is_binary(key) do
    get_in(emulator.config.input, [key])
  end

  @doc """
  Sets an environment variable.
  Returns the updated emulator.
  """
  @spec set_environment(Emulator.t(), String.t(), String.t()) :: Emulator.t()
  def set_environment(emulator, key, value) when is_binary(key) and is_binary(value) do
    input = Map.put(emulator.config.input, key, value)
    %{emulator | config: %{emulator.config | input: input}}
  end

  @doc """
  Gets all environment variables.
  Returns the map of environment variables.
  """
  @spec get_all_environment(Emulator.t()) :: %{String.t() => String.t()}
  def get_all_environment(emulator) do
    emulator.config.input
  end

  @doc """
  Sets multiple environment variables.
  Returns the updated emulator.
  """
  @spec set_environment_variables(Emulator.t(), %{String.t() => String.t()}) :: Emulator.t()
  def set_environment_variables(emulator, variables) when is_map(variables) do
    input = Map.merge(emulator.config.input, variables)
    %{emulator | config: %{emulator.config | input: input}}
  end

  @doc """
  Clears all environment variables.
  Returns the updated emulator.
  """
  @spec clear_environment(Emulator.t()) :: Emulator.t()
  def clear_environment(emulator) do
    %{emulator | config: %{emulator.config | input: %{}}}
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
