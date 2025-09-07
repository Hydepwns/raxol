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

  @persistent_config_file "~/.config/raxol/user_config.json"

  @doc """
  Starts the configuration manager.

  ## Options
    * `:config_file` - Path to the configuration file (default: "config/raxol.exs")
    * `:env` - Environment to load (default: Mix.env())
    * `:validate` - Whether to validate configuration (default: true)
    * `:persistent_file` - Path to persistent config file (default: "~/.config/raxol/user_config.json")

  ## Returns
    * `{:ok, pid}` - If the manager starts successfully
    * `{:error, reason}` - If the manager fails to start
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
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

  @impl GenServer
  def init(opts) do
    config_file = Keyword.get(opts, :config_file, "config/raxol.exs")
    env = Keyword.get(opts, :env, Mix.env())
    validate = Keyword.get(opts, :validate, true)

    persistent_file =
      Keyword.get(opts, :persistent_file, @persistent_config_file)

    state = %{
      config: %{},
      config_file: config_file,
      env: env,
      validate: validate,
      persistent_file: persistent_file
    }

    case load_config(state) do
      {:ok, new_state} ->
        {:ok, new_state}

      {:error, reason} ->
        Logger.warning("Failed to load config: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl GenServer
  def handle_call({:get, key, default}, _from, state) do
    value = Map.get(state.config, key, default)
    {:reply, value, state}
  end

  @impl GenServer
  def handle_call({:set, key, value, opts}, _from, state) do
    opts_with_persistent_file =
      Keyword.put(opts, :persistent_file, state.persistent_file)

    with :ok <- maybe_validate(key, value, state),
         :ok <- maybe_persist(key, value, opts_with_persistent_file) do
      new_state = %{state | config: Map.put(state.config, key, value)}
      {:reply, :ok, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:update, key, fun, opts}, _from, state) do
    current_value = Map.get(state.config, key)
    new_value = fun.(current_value)

    opts_with_persistent_file =
      Keyword.put(opts, :persistent_file, state.persistent_file)

    with :ok <- maybe_validate(key, new_value, state),
         :ok <- maybe_persist(key, new_value, opts_with_persistent_file) do
      new_state = %{state | config: Map.put(state.config, key, new_value)}
      {:reply, :ok, new_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:delete, key, opts}, _from, state) do
    opts_with_persistent_file =
      Keyword.put(opts, :persistent_file, state.persistent_file)

    case maybe_persist_delete(key, opts_with_persistent_file) do
      :ok ->
        new_state = %{state | config: Map.delete(state.config, key)}
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_all, _from, state) do
    {:reply, state.config, state}
  end

  @impl GenServer
  def handle_call(:reload, _from, state) do
    case load_config(state) do
      {:ok, new_state} ->
        {:reply, {:ok, new_state.config}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp load_config(state) do
    case load_config_file(state.config_file, state.env) do
      {:ok, config} ->
        {:ok, new_state} = maybe_validate_and_set_config(state, config)
        load_persistent_config(new_state)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_validate_and_set_config(%{validate: true} = state, config) do
    case validate_config(config) do
      :ok ->
        {:ok, %{state | config: config}}

      {:error, reason} ->
        Logger.warning("Configuration validation failed: #{reason}")
        {:ok, %{state | config: %{}}}
    end
  end

  defp maybe_validate_and_set_config(state, config) do
    {:ok, %{state | config: config}}
  end

  defp load_persistent_config(state) do
    case load_persistent_file(state.persistent_file) do
      {:ok, persistent_config} ->
        atom_config =
          Map.new(persistent_config, fn {k, v} -> {String.to_atom(k), v} end)

        merged_config = Map.merge(state.config, atom_config)
        {:ok, %{state | config: merged_config}}

      {:error, :file_not_found} ->
        {:ok, state}

      {:error, reason} ->
        Logger.warning("Failed to load persistent config: #{inspect(reason)}")
        {:ok, state}
    end
  end

  defp load_config_file(file, env) do
    case File.exists?(file) do
      true ->
        case Raxol.Core.ErrorHandling.safe_call(fn ->
               {config, _binding} = Code.eval_file(file)

               case get_in(config, [env]) do
                 nil -> {:ok, %{}}
                 env_config -> {:ok, env_config}
               end
             end) do
          {:ok, result} ->
            result

          {:error, {e, _stacktrace}} ->
            Logger.error("Failed to load config file: #{inspect(e)}")
            {:error, :invalid_config_file}
        end

      false ->
        Logger.warning("Config file not found: #{file}")
        {:ok, %{}}
    end
  end

  defp validate_config(config) do
    required_fields = [:terminal, :buffer, :renderer]

    missing_fields =
      Enum.filter(required_fields, &(not Map.has_key?(config, &1)))

    case Enum.empty?(missing_fields) do
      true ->
        validate_terminal_config(config.terminal)
        validate_buffer_config(config.buffer)
        validate_renderer_config(config.renderer)

      false ->
        {:error,
         "Missing required configuration fields: #{Enum.join(missing_fields, ", ")}"}
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

    case Enum.empty?(missing_fields) do
      true ->
        :ok

      false ->
        {:error,
         "Missing required #{section} configuration fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp maybe_validate(_key, _value, %{validate: false}), do: :ok

  defp maybe_validate(key, value, _state) do
    case validate_value(key, value) do
      :ok -> :ok
      {:error, reason} -> {:error, "Invalid value for #{key}: #{reason}"}
    end
  end

  defp validate_value(:terminal_width, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_value(:terminal_height, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_value(:terminal_mode, value) when value in [:normal, :raw],
    do: :ok

  defp validate_value(:buffer_max_size, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_value(:buffer_scrollback, value)
       when is_integer(value) and value >= 0,
       do: :ok

  defp validate_value(:renderer_mode, value) when value in [:gpu, :cpu], do: :ok

  defp validate_value(:renderer_double_buffering, value) when is_boolean(value),
    do: :ok

  defp validate_value(_key, _value), do: {:error, "Invalid value"}

  defp maybe_persist(key, value, opts) do
    case Keyword.get(opts, :persist, true) do
      true -> persist_config_change(key, value, opts)
      false -> :ok
    end
  end

  defp maybe_persist_delete(key, opts) do
    case Keyword.get(opts, :persist, true) do
      true -> persist_config_deletion(key, opts)
      false -> :ok
    end
  end

  defp persist_config_change(key, value, opts) do
    persistent_file =
      Keyword.get(opts, :persistent_file, @persistent_config_file)

    persistent_file
    |> Path.dirname()
    |> File.mkdir_p()

    current_config = load_existing_persistent_config(persistent_file)

    updated_config = Map.put(current_config, Atom.to_string(key), value)

    case Jason.encode(updated_config, pretty: true) do
      {:ok, json_content} ->
        case File.write(persistent_file, json_content) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error("Failed to persist config change: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to encode config: #{inspect(reason)}")
        {:error, :encoding_failed}
    end
  end

  defp persist_config_deletion(key, opts) do
    persistent_file =
      Keyword.get(opts, :persistent_file, @persistent_config_file)

    current_config = load_existing_persistent_config(persistent_file)

    updated_config = Map.delete(current_config, Atom.to_string(key))

    case Jason.encode(updated_config, pretty: true) do
      {:ok, json_content} ->
        case File.write(persistent_file, json_content) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.error(
              "Failed to persist config deletion: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to encode config: #{inspect(reason)}")
        {:error, :encoding_failed}
    end
  end

  defp load_existing_persistent_config(persistent_file) do
    case load_persistent_file(persistent_file) do
      {:ok, config} -> config
      _ -> %{}
    end
  end

  defp load_persistent_file(file_path) do
    expanded_path = Path.expand(file_path)

    case File.exists?(expanded_path) do
      true ->
        case File.read(expanded_path) do
          {:ok, content} -> decode_json_content(content)
          {:error, reason} -> {:error, reason}
        end

      false ->
        {:error, :file_not_found}
    end
  end

  defp decode_json_content(content) do
    case Jason.decode(content) do
      {:ok, config} when is_map(config) -> {:ok, config}
      {:ok, _} -> {:error, :invalid_config_format}
      {:error, reason} -> {:error, reason}
    end
  end
end
