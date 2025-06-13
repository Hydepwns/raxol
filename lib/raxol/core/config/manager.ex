defmodule Raxol.Core.Config.Manager do
  @moduledoc """
  Configuration manager for the Raxol Terminal Emulator.
  Provides a unified interface for managing all configuration options,
  including loading, validation, and runtime updates.
  """

  use GenServer
  require Logger

  @type config_key :: atom()
  @type config_value :: term()
  @type config_opts :: keyword()
  @type validation_result :: :ok | {:error, String.t()}

  # Client API

  @doc """
  Starts the configuration manager.

  ## Options
    * `:config_file` - Path to the configuration file (default: "config/raxol.exs")
    * `:env` - Environment to load (default: Mix.env())
    * `:validate` - Whether to validate configuration (default: true)

  ## Returns
    * `{:ok, pid}` - If the manager starts successfully
    * `{:error, reason}` - If the manager fails to start
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a configuration value.

  ## Parameters
    * `key` - The configuration key
    * `default` - Default value if key is not found (optional)

  ## Returns
    * The configuration value or default
  """
  def get(key, default \\ nil) do
    GenServer.call(__MODULE__, {:get, key, default})
  end

  @doc """
  Sets a configuration value.

  ## Parameters
    * `key` - The configuration key
    * `value` - The configuration value
    * `opts` - Additional options
      * `:validate` - Whether to validate the value (default: true)
      * `:persist` - Whether to persist the value (default: true)

  ## Returns
    * `:ok` - If the value was set successfully
    * `{:error, reason}` - If the value could not be set
  """
  def set(key, value, opts \\ []) do
    GenServer.call(__MODULE__, {:set, key, value, opts})
  end

  @doc """
  Updates a configuration value using a function.

  ## Parameters
    * `key` - The configuration key
    * `fun` - Function to update the value
    * `opts` - Additional options
      * `:validate` - Whether to validate the value (default: true)
      * `:persist` - Whether to persist the value (default: true)

  ## Returns
    * `:ok` - If the value was updated successfully
    * `{:error, reason}` - If the value could not be updated
  """
  def update(key, fun, opts \\ []) when is_function(fun, 1) do
    GenServer.call(__MODULE__, {:update, key, fun, opts})
  end

  @doc """
  Deletes a configuration value.

  ## Parameters
    * `key` - The configuration key
    * `opts` - Additional options
      * `:persist` - Whether to persist the deletion (default: true)

  ## Returns
    * `:ok` - If the value was deleted successfully
    * `{:error, reason}` - If the value could not be deleted
  """
  def delete(key, opts \\ []) do
    GenServer.call(__MODULE__, {:delete, key, opts})
  end

  @doc """
  Gets all configuration values.

  ## Returns
    * Map of all configuration values
  """
  def get_all do
    GenServer.call(__MODULE__, :get_all)
  end

  @doc """
  Reloads configuration from the file.

  ## Returns
    * `:ok` - If the configuration was reloaded successfully
    * `{:error, reason}` - If the configuration could not be reloaded
  """
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    config_file = Keyword.get(opts, :config_file, "config/raxol.exs")
    env = Keyword.get(opts, :env, Mix.env())
    validate = Keyword.get(opts, :validate, true)

    state = %{
      config: %{},
      config_file: config_file,
      env: env,
      validate: validate
    }

    case load_config(state) do
      {:ok, new_state} -> {:ok, new_state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call({:get, key, default}, _from, state) do
    value = Map.get(state.config, key, default)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:set, key, value, opts}, _from, state) do
    with :ok <- maybe_validate(key, value, state),
         :ok <- maybe_persist(key, value, opts) do
      new_state = put_in(state.config[key], value)
      {:reply, :ok, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update, key, fun, opts}, _from, state) do
    current_value = Map.get(state.config, key)
    new_value = fun.(current_value)

    with :ok <- maybe_validate(key, new_value, state),
         :ok <- maybe_persist(key, new_value, opts) do
      new_state = put_in(state.config[key], new_value)
      {:reply, :ok, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete, key, opts}, _from, state) do
    with :ok <- maybe_persist_delete(key, opts) do
      new_state = update_in(state.config, &Map.delete(&1, key))
      {:reply, :ok, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_all, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    case load_config(state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # Private Functions

  defp load_config(state) do
    case load_config_file(state.config_file, state.env) do
      {:ok, config} ->
        if state.validate do
          case validate_config(config) do
            :ok -> {:ok, %{state | config: config}}
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, %{state | config: config}}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_config_file(file, env) do
    if File.exists?(file) do
      try do
        config = Code.eval_file(file)
        {:ok, get_in(config, [env])}
      rescue
        e ->
          Logger.error("Failed to load config file: #{inspect(e)}")
          {:error, :invalid_config_file}
      end
    else
      Logger.warning("Config file not found: #{file}")
      {:ok, %{}}
    end
  end

  defp validate_config(config) do
    # Validate required fields
    required_fields = [:terminal, :buffer, :renderer]
    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing_fields) do
      # Validate each section
      with :ok <- validate_terminal_config(config.terminal),
           :ok <- validate_buffer_config(config.buffer),
           :ok <- validate_renderer_config(config.renderer) do
        :ok
      end
    else
      {:error, "Missing required configuration fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_terminal_config(config) do
    required_fields = [:width, :height, :mode]
    validate_required_fields(config, required_fields, "terminal")
  end

  defp validate_buffer_config(config) do
    required_fields = [:max_size, :scrollback]
    validate_required_fields(config, required_fields, "buffer")
  end

  defp validate_renderer_config(config) do
    required_fields = [:mode, :double_buffering]
    validate_required_fields(config, required_fields, "renderer")
  end

  defp validate_required_fields(config, fields, section) do
    missing_fields = Enum.filter(fields, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required #{section} configuration fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp maybe_validate(_key, _value, %{validate: false}), do: :ok
  defp maybe_validate(key, value, state) do
    case validate_value(key, value) do
      :ok -> :ok
      {:error, reason} -> {:error, "Invalid value for #{key}: #{reason}"}
    end
  end

  defp validate_value(:terminal_width, value) when is_integer(value) and value > 0, do: :ok
  defp validate_value(:terminal_height, value) when is_integer(value) and value > 0, do: :ok
  defp validate_value(:terminal_mode, value) when value in [:normal, :raw], do: :ok
  defp validate_value(:buffer_max_size, value) when is_integer(value) and value > 0, do: :ok
  defp validate_value(:buffer_scrollback, value) when is_integer(value) and value >= 0, do: :ok
  defp validate_value(:renderer_mode, value) when value in [:gpu, :cpu], do: :ok
  defp validate_value(:renderer_double_buffering, value) when is_boolean(value), do: :ok
  defp validate_value(_key, _value), do: {:error, "Invalid value"}

  defp maybe_persist(_key, _value, %{persist: false}), do: :ok
  defp maybe_persist(key, value, _opts) do
    # TODO: Implement configuration persistence
    :ok
  end

  defp maybe_persist_delete(_key, %{persist: false}), do: :ok
  defp maybe_persist_delete(key, _opts) do
    # TODO: Implement configuration persistence
    :ok
  end
end
