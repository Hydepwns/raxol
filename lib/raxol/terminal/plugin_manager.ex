defmodule Raxol.Terminal.PluginManager do
  @moduledoc """
  Manages terminal plugins including loading, unloading, and hook execution.
  This module is responsible for plugin lifecycle and interaction with the terminal.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Core.Runtime.Plugins.Manager
  require Raxol.Core.Runtime.Log

  @doc """
  Gets the plugin manager instance.
  Returns the plugin manager.
  """
  @spec get_manager(Emulator.t()) :: Manager.t()
  def get_manager(emulator) do
    emulator.plugin_manager
  end

  @doc """
  Updates the plugin manager instance.
  Returns the updated emulator.
  """
  @spec update_manager(Emulator.t(), Manager.t()) :: Emulator.t()
  def update_manager(emulator, manager) do
    %{emulator | plugin_manager: manager}
  end

  @doc """
  Initializes a plugin with the given configuration.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec initialize_plugin(Emulator.t(), String.t(), map()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def initialize_plugin(emulator, plugin_name, config) do
    case Manager.initialize_plugin(emulator.plugin_manager, plugin_name, config) do
      {:ok, new_manager} ->
        {:ok, update_manager(emulator, new_manager)}

      {:error, reason} ->
        {:error,
         "Failed to initialize plugin #{plugin_name}: #{inspect(reason)}"}
    end
  end

  @doc """
  Calls a plugin hook with the given arguments.
  Returns {:ok, updated_emulator, result} or {:error, reason}.
  """
  @spec call_hook(Emulator.t(), String.t(), String.t(), list()) ::
          {:ok, Emulator.t(), any()} | {:error, String.t()}
  def call_hook(emulator, plugin_name, hook_name, args) do
    case Manager.call_hook(
           emulator.plugin_manager,
           plugin_name,
           hook_name,
           args
         ) do
      {:ok, new_manager, result} ->
        {:ok, update_manager(emulator, new_manager), result}

      {:error, reason} ->
        {:error,
         "Failed to call hook #{hook_name} on plugin #{plugin_name}: #{inspect(reason)}"}
    end
  end

  @doc """
  Checks if a plugin is loaded.
  Returns true if the plugin is loaded, false otherwise.
  """
  @spec plugin_loaded?(Emulator.t(), String.t()) :: boolean()
  def plugin_loaded?(emulator, plugin_name) do
    Manager.plugin_loaded?(emulator.plugin_manager, plugin_name)
  end

  @doc """
  Gets the list of loaded plugins.
  Returns the list of loaded plugin names.
  """
  @spec get_loaded_plugins(Emulator.t()) :: list(String.t())
  def get_loaded_plugins(emulator) do
    Manager.get_loaded_plugins(emulator.plugin_manager)
  end

  @doc """
  Unloads a plugin.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec unload_plugin(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def unload_plugin(emulator, plugin_name) do
    # Manager.unload_plugin uses GenServer.cast and returns :ok
    Manager.unload_plugin(emulator.plugin_manager, plugin_name)
    {:ok, emulator}
  end

  @doc """
  Gets a plugin's configuration.
  Returns {:ok, config} or {:error, reason}.
  """
  @spec get_plugin_config(Emulator.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def get_plugin_config(emulator, plugin_name) do
    case Manager.get_plugin_config(emulator.plugin_manager, plugin_name) do
      {:ok, config} ->
        {:ok, config}

      {:error, reason} ->
        {:error,
         "Failed to get config for plugin #{plugin_name}: #{inspect(reason)}"}
    end
  end

  @doc """
  Updates a plugin's configuration.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec update_plugin_config(Emulator.t(), String.t(), map()) ::
          {:ok, Emulator.t()} | {:error, String.t()}
  def update_plugin_config(emulator, plugin_name, config) do
    # Manager.update_plugin_config uses GenServer.cast and returns :ok
    Manager.update_plugin_config(emulator.plugin_manager, plugin_name, config)
    {:ok, emulator}
  end

  @doc """
  Validates a plugin's configuration.
  Returns :ok or {:error, reason}.
  """
  @spec validate_plugin_config(String.t(), map()) :: :ok | {:error, String.t()}
  def validate_plugin_config(plugin_name, config) do
    case Manager.validate_plugin_config(plugin_name, config) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, "Invalid config for plugin #{plugin_name}: #{inspect(reason)}"}
    end
  end
end
