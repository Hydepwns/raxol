defmodule Raxol.Core.Runtime.Plugins.API do
  @moduledoc """
  Public API for Raxol plugins to interact with the core system.

  This module provides standardized interfaces for plugins to:
  - Register event handlers
  - Access runtime services
  - Register commands
  - Access rendering capabilities
  - Modify application state in approved ways

  Plugin developers should only use these API functions for interacting with
  the Raxol system to ensure forward compatibility when the internal system changes.
  """

  # --- Event Management ---
  alias Raxol.Core.Events.EventManager, as: EventManager

  @doc """
  Subscribe to runtime events.

  ## Parameters

  - `event_type` - The type of event to subscribe to
  - `handler` - Module that will handle the event
  - `function` - Function in the handler module that will be called (default: :handle_event)

  ## Returns

  - `:ok` if successful
  - `{:error, reason}` if subscription failed

  ## Example

  ```elixir
  API.subscribe(:key_press, MyPluginHandlers)
  ```
  """
  @spec subscribe(atom(), module(), atom()) :: :ok | {:error, term()}
  def subscribe(event_type, handler, function \\ :handle_event) do
    EventManager.register_handler(event_type, handler, function)
  end

  @doc """
  Unsubscribe from runtime events.

  ## Parameters

  - `event_type` - The type of event to unsubscribe from
  - `handler` - Module to unsubscribe

  ## Returns

  - `:ok` if successful
  - `{:error, reason}` if unsubscription failed
  """
  @spec unsubscribe(atom(), module()) :: :ok | {:error, term()}
  def unsubscribe(event_type, handler) do
    EventManager.unregister_handler(event_type, handler, :handle_event)
  end

  @doc """
  Broadcast an event to all subscribers.

  ## Parameters

  - `event_type` - The type of event to broadcast
  - `payload` - Data to include with the event

  ## Returns

  - `:ok` if broadcast was successful
  """
  @spec broadcast(atom(), map()) :: :ok
  def broadcast(event_type, payload) do
    EventManager.dispatch({event_type, payload})
  end

  @doc """
  Creates a new screen buffer with the specified dimensions.

  ## Parameters
    * `width` - The width of the buffer
    * `height` - The height of the buffer
    * `options` - Additional options for buffer creation

  ## Returns
    A new screen buffer instance
  """
  def create_buffer(width, height, options \\ []) do
    Raxol.Core.Runtime.Log.debug(
      "Plugin API: create_buffer(#{width}, #{height}, #{inspect(options)})"
    )

    Raxol.Terminal.ScreenBuffer.new(width, height)
  end

  @doc """
  Get the current application configuration.

  ## Parameters

  - `key` - The configuration key to retrieve
  - `default` - Default value if the key is not found

  ## Returns

  The configuration value or default
  """
  @spec get_config(atom() | String.t(), term()) :: term()
  def get_config(key, default \\ nil) do
    Raxol.Core.Runtime.Application.get_env(:raxol, key, default)
  end

  @doc """
  Get the path to the plugin data directory.

  ## Parameters

  - `plugin_id` - The ID of the plugin

  ## Returns

  String path to the plugin's data directory
  """
  @spec plugin_data_dir(String.t()) :: String.t()
  def plugin_data_dir(plugin_id) do
    base_path =
      Raxol.Core.Runtime.Application.get_env(
        :raxol,
        :plugin_data_path,
        "priv/data/plugins"
      )

    Path.join(base_path, plugin_id)
  end

  @doc """
  Log a message from a plugin.

  ## Parameters

  - `plugin_id` - The ID of the plugin
  - `level` - Log level (:debug, :info, :warn, :error)
  - `message` - The message to log

  ## Returns

  `:ok`
  """
  @spec log(String.t(), atom(), String.t()) :: :ok
  def log(plugin_id, level, message) do
    prefix = "[Plugin:#{plugin_id}]"

    case level do
      :debug -> Raxol.Core.Runtime.Debug.debug("#{prefix} #{message}")
      :info -> Raxol.Core.Runtime.Debug.info("#{prefix} #{message}")
      :warn -> Raxol.Core.Runtime.Debug.warn("#{prefix} #{message}")
      :error -> Raxol.Core.Runtime.Debug.error("#{prefix} #{message}")
      _ -> Raxol.Core.Runtime.Debug.info("#{prefix} #{message}")
    end

    :ok
  end
end
