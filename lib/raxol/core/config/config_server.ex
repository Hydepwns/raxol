defmodule Raxol.Core.Config.ConfigServer do
  @moduledoc """
  Backward-compatible configuration server.

  This module maintains the original API but delegates to the pure functional
  `Raxol.Core.Config` module and ETS-backed `Raxol.Core.Config.Store`.

  ## Migration Note

  This module is retained for backward compatibility. New code should use:
  - `Raxol.Core.Config` for pure functional operations on config data
  - `Raxol.Core.Config.Store` for runtime config access with ETS backing

  ## Architecture Change

  Previous: All operations serialized through GenServer mailbox
  Current: Reads go directly to ETS, writes coordinate through GenServer

  This change improves:
  - Read performance (no mailbox serialization)
  - Concurrent access (ETS read_concurrency)
  - Code clarity (pure functions separated from process management)
  """

  alias Raxol.Core.Config
  alias Raxol.Core.Config.Store

  @type config_namespace :: Config.namespace()
  @type config_key :: Config.key()
  @type config_value :: Config.value()

  @doc """
  Starts the configuration store.

  Kept for backward compatibility - delegates to Config.Store.
  """
  def start_link(opts \\ []) do
    Store.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Gets configuration value from specified namespace and key.

  This is now a direct ETS read - fast and concurrent.
  """
  @spec get(GenServer.server(), config_namespace(), config_key(), any()) ::
          any()
  def get(_server \\ __MODULE__, namespace, key, default \\ nil) do
    Store.get(namespace, key, default)
  end

  @doc """
  Sets configuration value in specified namespace and key.
  """
  @spec set(
          GenServer.server(),
          config_namespace(),
          config_key(),
          config_value()
        ) ::
          :ok | {:error, any()}
  def set(_server \\ __MODULE__, namespace, key, value) do
    Store.put(namespace, key, value)
  end

  @doc """
  Gets entire namespace configuration.

  Direct ETS read - fast and concurrent.
  """
  @spec get_namespace(GenServer.server(), config_namespace()) :: map()
  def get_namespace(_server \\ __MODULE__, namespace) do
    Store.get_namespace(namespace)
  end

  @doc """
  Sets entire namespace configuration.
  """
  @spec set_namespace(GenServer.server(), config_namespace(), map()) :: :ok
  def set_namespace(_server \\ __MODULE__, namespace, config) do
    Store.put_namespace(namespace, config)
  end

  @doc """
  Loads configuration from file system.
  """
  @spec load_from_file(GenServer.server()) :: :ok | {:error, any()}
  def load_from_file(_server \\ __MODULE__) do
    Store.load_from_file()
  end

  @doc """
  Saves configuration to file system.
  """
  @spec save_to_file(GenServer.server()) :: :ok | {:error, any()}
  def save_to_file(_server \\ __MODULE__) do
    Store.save_to_file()
  end

  @doc """
  Validates configuration for specified namespace.
  """
  @spec validate(GenServer.server(), config_namespace()) ::
          :ok | {:error, [String.t()]}
  def validate(_server \\ __MODULE__, namespace) do
    config = Store.get_namespace(namespace)
    Config.validate_namespace(namespace, config)
  end

  @doc """
  Resets namespace to default configuration.
  """
  @spec reset_namespace(GenServer.server(), config_namespace()) :: :ok
  def reset_namespace(_server \\ __MODULE__, namespace) do
    Store.reset_namespace(namespace)
  end
end
