defmodule Raxol.Core.Config.ConfigServer do
  @moduledoc """
  Unified configuration management system for Raxol.
  Consolidates configuration from multiple specialized config modules:
  - PluginConfig
  - TerminalConfig
  - PerformanceConfig
  - SecurityConfig
  - BenchmarkConfig
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  @config_dir ".config/raxol"
  @main_config_file "raxol.toml"

  defstruct [
    :version,
    :terminal,
    :plugins,
    :performance,
    :security,
    :ui,
    :benchmark,
    :persistence
  ]

  @type config_namespace ::
          :terminal | :plugins | :performance | :security | :ui | :benchmark
  @type config_key :: atom() | String.t()
  @type config_value :: any()

  @type t :: %__MODULE__{
          version: String.t(),
          terminal: map(),
          plugins: map(),
          performance: map(),
          security: map(),
          ui: map(),
          benchmark: map(),
          persistence: map()
        }

  ## Client API

  @doc """
  Gets configuration value from specified namespace and key.
  """
  @spec get(GenServer.server(), config_namespace(), config_key(), any()) ::
          any()
  def get(server \\ __MODULE__, namespace, key, default \\ nil) do
    GenServer.call(server, {:get, namespace, key, default})
  end

  @doc """
  Sets configuration value in specified namespace and key.
  """
  @spec set(
          GenServer.server(),
          config_namespace(),
          config_key(),
          config_value()
        ) :: :ok | {:error, any()}
  def set(server \\ __MODULE__, namespace, key, value) do
    GenServer.call(server, {:set, namespace, key, value})
  end

  @doc """
  Gets entire namespace configuration.
  """
  @spec get_namespace(GenServer.server(), config_namespace()) :: map()
  def get_namespace(server \\ __MODULE__, namespace) do
    GenServer.call(server, {:get_namespace, namespace})
  end

  @doc """
  Sets entire namespace configuration.
  """
  @spec set_namespace(GenServer.server(), config_namespace(), map()) ::
          :ok | {:error, any()}
  def set_namespace(server \\ __MODULE__, namespace, config) do
    GenServer.call(server, {:set_namespace, namespace, config})
  end

  @doc """
  Loads configuration from file system.
  """
  @spec load_from_file(GenServer.server()) :: :ok | {:error, any()}
  def load_from_file(server \\ __MODULE__) do
    GenServer.call(server, :load_from_file)
  end

  @doc """
  Saves configuration to file system.
  """
  @spec save_to_file(GenServer.server()) :: :ok | {:error, any()}
  def save_to_file(server \\ __MODULE__) do
    GenServer.call(server, :save_to_file)
  end

  @doc """
  Validates configuration for specified namespace.
  """
  @spec validate(GenServer.server(), config_namespace()) ::
          :ok | {:error, [String.t()]}
  def validate(server \\ __MODULE__, namespace) do
    GenServer.call(server, {:validate, namespace})
  end

  @doc """
  Resets namespace to default configuration.
  """
  @spec reset_namespace(GenServer.server(), config_namespace()) :: :ok
  def reset_namespace(server \\ __MODULE__, namespace) do
    GenServer.call(server, {:reset_namespace, namespace})
  end

  ## BaseManager Implementation

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    config = %__MODULE__{
      version: "1.5.4",
      terminal: default_terminal_config(),
      plugins: default_plugins_config(),
      performance: default_performance_config(),
      security: default_security_config(),
      ui: default_ui_config(),
      benchmark: default_benchmark_config(),
      persistence: %{
        auto_save: Keyword.get(opts, :auto_save, true),
        save_interval: Keyword.get(opts, :save_interval, 30_000)
      }
    }

    # Load from file if it exists
    final_config =
      case load_config_from_file() do
        {:ok, loaded_config} -> merge_configs(config, loaded_config)
        {:error, _reason} -> config
      end

    if final_config.persistence.auto_save do
      schedule_auto_save(final_config.persistence.save_interval)
    end

    {:ok, final_config}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get, namespace, key, default}, _from, state) do
    namespace_config = Map.get(state, namespace, %{})
    value = Map.get(namespace_config, key, default)
    {:reply, value, state}
  end

  def handle_manager_call({:set, namespace, key, value}, _from, state) do
    case validate_config_value(namespace, key, value) do
      :ok ->
        namespace_config = Map.get(state, namespace, %{})
        updated_namespace = Map.put(namespace_config, key, value)
        new_state = Map.put(state, namespace, updated_namespace)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call({:get_namespace, namespace}, _from, state) do
    namespace_config = Map.get(state, namespace, %{})
    {:reply, namespace_config, state}
  end

  def handle_manager_call({:set_namespace, namespace, config}, _from, state) do
    case validate_namespace_config(namespace, config) do
      :ok ->
        new_state = Map.put(state, namespace, config)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(:load_from_file, _from, state) do
    case load_config_from_file() do
      {:ok, loaded_config} ->
        merged_config = merge_configs(state, loaded_config)
        {:reply, :ok, merged_config}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(:save_to_file, _from, state) do
    case save_config_to_file(state) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call({:validate, namespace}, _from, state) do
    namespace_config = Map.get(state, namespace, %{})
    result = validate_namespace_config(namespace, namespace_config)
    {:reply, result, state}
  end

  def handle_manager_call({:reset_namespace, namespace}, _from, state) do
    default_config = get_default_namespace_config(namespace)
    new_state = Map.put(state, namespace, default_config)
    {:reply, :ok, new_state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:auto_save, state) do
    case save_config_to_file(state) do
      :ok ->
        Log.module_debug("Auto-saved configuration successfully")

      {:error, reason} ->
        Log.module_warning("Auto-save failed: #{inspect(reason)}")
    end

    schedule_auto_save(state.persistence.save_interval)
    {:noreply, state}
  end

  ## Private Functions - Default Configurations

  defp default_terminal_config do
    %{
      width: 80,
      height: 24,
      colors: %{
        foreground: "#ffffff",
        background: "#000000",
        cursor: "#ffffff"
      },
      input: %{
        mouse_enabled: true,
        paste_mode: :bracketed
      },
      performance: %{
        render_fps: 60,
        buffer_size: 1000
      }
    }
  end

  defp default_plugins_config do
    %{
      enabled_plugins: [],
      plugin_configs: %{},
      auto_load: true,
      search_paths: ["~/.raxol/plugins", "./plugins"]
    }
  end

  defp default_performance_config do
    %{
      parser_cache_size: 1000,
      render_cache_enabled: true,
      memory_limit_mb: 100,
      gc_threshold: 0.8
    }
  end

  defp default_security_config do
    %{
      encryption_enabled: false,
      key_rotation_hours: 24,
      audit_logging: true,
      max_session_duration: 86400
    }
  end

  defp default_ui_config do
    %{
      theme: "default",
      animations_enabled: true,
      transition_duration: 200,
      component_cache_size: 100
    }
  end

  defp default_benchmark_config do
    %{
      warmup_time: 1000,
      measurement_time: 5000,
      memory_time: 2000,
      parallel_jobs: 1
    }
  end

  defp get_default_namespace_config(namespace) do
    case namespace do
      :terminal -> default_terminal_config()
      :plugins -> default_plugins_config()
      :performance -> default_performance_config()
      :security -> default_security_config()
      :ui -> default_ui_config()
      :benchmark -> default_benchmark_config()
      _ -> %{}
    end
  end

  ## Private Functions - File Operations

  defp load_config_from_file do
    config_path = Path.join(config_dir(), @main_config_file)

    case File.read(config_path) do
      {:ok, content} -> parse_config_content(content)
      {:error, :enoent} -> {:error, :file_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp save_config_to_file(config) do
    config_path = Path.join(config_dir(), @main_config_file)

    with :ok <- ensure_config_dir(),
         {:ok, content} <- encode_config(config),
         :ok <- File.write(config_path, content) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_config_content(content) do
    # For simplicity, using JSON. In practice, could use TOML parser
    case Jason.decode(content) do
      {:ok, decoded} -> {:ok, atomize_keys(decoded)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp encode_config(config) do
    # Convert to JSON for storage
    case Jason.encode(config, pretty: true) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end

  defp config_dir do
    case System.get_env("XDG_CONFIG_HOME") do
      nil -> Path.join(System.user_home!(), @config_dir)
      xdg_home -> Path.join(xdg_home, "raxol")
    end
  end

  defp ensure_config_dir do
    config_path = config_dir()

    case File.mkdir_p(config_path) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Functions - Validation

  defp validate_config_value(:terminal, :width, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_config_value(:terminal, :height, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_config_value(:performance, :memory_limit_mb, value)
       when is_integer(value) and value > 0,
       do: :ok

  defp validate_config_value(:security, :max_session_duration, value)
       when is_integer(value) and value > 0,
       do: :ok

  # Default to allowing all values
  defp validate_config_value(_namespace, _key, _value), do: :ok

  # Simplified validation
  defp validate_namespace_config(_namespace, _config), do: :ok

  ## Private Functions - Utilities

  defp merge_configs(base, override) do
    Map.merge(base, override, fn
      _key, base_val, override_val
      when is_map(base_val) and is_map(override_val) ->
        Map.merge(base_val, override_val)

      _key, _base_val, override_val ->
        override_val
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_atom(key), else: key
      Map.put(acc, atom_key, atomize_keys(value))
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  defp schedule_auto_save(interval) do
    Process.send_after(self(), :auto_save, interval)
  end
end
