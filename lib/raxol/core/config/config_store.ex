defmodule Raxol.Core.Config.Store do
  @moduledoc """
  ETS-backed configuration store for fast concurrent reads.

  This module provides the runtime storage layer for configuration.
  It uses ETS for fast concurrent reads (no process serialization)
  and a minimal GenServer only for initialization and file persistence.

  ## Design

  - ETS for all reads: No mailbox serialization, multiple readers can access concurrently
  - GenServer only for: Initialization, file I/O, auto-save timer
  - Pure functions from `Raxol.Core.Config` for all data transformations

  ## Usage

      # Start the store (usually in supervision tree)
      {:ok, _pid} = Config.Store.start_link([])

      # Read (fast ETS lookup, no process call)
      width = Config.Store.get(:terminal, :width)
      terminal = Config.Store.get_namespace(:terminal)

      # Write (goes through GenServer for consistency)
      Config.Store.put(:terminal, :width, 120)

      # File operations
      Config.Store.load_from_file()
      Config.Store.save_to_file()
  """

  use GenServer
  alias Raxol.Core.Config
  alias Raxol.Core.Runtime.Log

  @table_name :raxol_config
  @config_dir ".config/raxol"
  @config_file "raxol.toml"

  # ============================================================================
  # Client API - Reads (Direct ETS, no GenServer call)
  # ============================================================================

  @doc """
  Gets a config value. This is a direct ETS read - no process serialization.

  ## Examples

      Config.Store.get(:terminal, :width)
      Config.Store.get(:terminal, :missing, 0)
  """
  @spec get(Config.namespace(), Config.key(), Config.value()) :: Config.value()
  def get(namespace, key, default \\ nil) do
    case :ets.lookup(@table_name, :config) do
      [{:config, config}] -> Config.get(config, namespace, key, default)
      [] -> default
    end
  end

  @doc """
  Gets an entire namespace. Direct ETS read.

  ## Examples

      Config.Store.get_namespace(:terminal)
  """
  @spec get_namespace(Config.namespace()) :: map()
  def get_namespace(namespace) do
    case :ets.lookup(@table_name, :config) do
      [{:config, config}] -> Config.get_namespace(config, namespace)
      [] -> %{}
    end
  end

  @doc """
  Gets the entire config. Direct ETS read.
  """
  @spec get_all() :: Config.t()
  def get_all do
    case :ets.lookup(@table_name, :config) do
      [{:config, config}] -> config
      [] -> Config.new()
    end
  end

  # ============================================================================
  # Client API - Writes (Through GenServer for consistency)
  # ============================================================================

  @doc """
  Sets a config value.

  ## Examples

      Config.Store.put(:terminal, :width, 120)
  """
  @spec put(Config.namespace(), Config.key(), Config.value()) ::
          :ok | {:error, String.t()}
  def put(namespace, key, value) do
    GenServer.call(__MODULE__, {:put, namespace, key, value})
  end

  @doc """
  Sets an entire namespace.

  ## Examples

      Config.Store.put_namespace(:terminal, %{width: 120, height: 40})
  """
  @spec put_namespace(Config.namespace(), map()) :: :ok
  def put_namespace(namespace, namespace_config) do
    GenServer.call(__MODULE__, {:put_namespace, namespace, namespace_config})
  end

  @doc """
  Resets a namespace to default values.
  """
  @spec reset_namespace(Config.namespace()) :: :ok
  def reset_namespace(namespace) do
    GenServer.call(__MODULE__, {:reset_namespace, namespace})
  end

  # ============================================================================
  # Client API - File Operations
  # ============================================================================

  @doc """
  Loads config from file, merging with current config.
  """
  @spec load_from_file() :: :ok | {:error, any()}
  def load_from_file do
    GenServer.call(__MODULE__, :load_from_file)
  end

  @doc """
  Saves current config to file.
  """
  @spec save_to_file() :: :ok | {:error, any()}
  def save_to_file do
    GenServer.call(__MODULE__, :save_to_file)
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    # Create ETS table with read_concurrency for fast reads
    :ets.new(@table_name, [
      :named_table,
      :public,
      :set,
      read_concurrency: true
    ])

    # Initialize with defaults
    config = Config.new()

    # Try to load from file
    config =
      case load_config_file() do
        {:ok, loaded} -> Config.merge(config, loaded)
        {:error, _} -> config
      end

    # Store in ETS
    :ets.insert(@table_name, {:config, config})

    # Set up auto-save if enabled
    auto_save = Keyword.get(opts, :auto_save, true)
    interval = Keyword.get(opts, :save_interval, 30_000)

    state = %{
      auto_save: auto_save,
      save_interval: interval
    }

    if auto_save do
      schedule_auto_save(interval)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:put, namespace, key, value}, _from, state) do
    case Config.validate_value(namespace, key, value) do
      :ok ->
        update_config(fn config ->
          Config.put(config, namespace, key, value)
        end)

        {:reply, :ok, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:put_namespace, namespace, namespace_config}, _from, state) do
    update_config(fn config ->
      Config.put_namespace(config, namespace, namespace_config)
    end)

    {:reply, :ok, state}
  end

  def handle_call({:reset_namespace, namespace}, _from, state) do
    update_config(fn config -> Config.reset_namespace(config, namespace) end)
    {:reply, :ok, state}
  end

  def handle_call(:load_from_file, _from, state) do
    case load_config_file() do
      {:ok, loaded} ->
        update_config(fn config -> Config.merge(config, loaded) end)
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:save_to_file, _from, state) do
    result = save_current_config()
    {:reply, result, state}
  end

  @impl GenServer
  def handle_info(:auto_save, state) do
    case save_current_config() do
      :ok ->
        Log.debug("Config auto-saved successfully")

      {:error, reason} ->
        Log.warning("Config auto-save failed: #{inspect(reason)}")
    end

    if state.auto_save do
      schedule_auto_save(state.save_interval)
    end

    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp update_config(fun) do
    config = get_all()
    new_config = fun.(config)
    :ets.insert(@table_name, {:config, new_config})
    :ok
  end

  defp load_config_file do
    path = config_path()

    case File.read(path) do
      {:ok, content} -> Config.from_json(content)
      {:error, :enoent} -> {:error, :file_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_current_config do
    config = get_all()

    with {:ok, json} <- Config.to_json(config),
         :ok <- ensure_config_dir(),
         :ok <- File.write(config_path(), json) do
      :ok
    end
  end

  defp config_path do
    Path.join(config_dir(), @config_file)
  end

  defp config_dir do
    case System.get_env("XDG_CONFIG_HOME") do
      nil -> Path.join(System.user_home!(), @config_dir)
      xdg -> Path.join(xdg, "raxol")
    end
  end

  defp ensure_config_dir do
    File.mkdir_p(config_dir())
  end

  defp schedule_auto_save(interval) do
    Process.send_after(self(), :auto_save, interval)
  end
end
