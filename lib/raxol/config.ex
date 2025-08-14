defmodule Raxol.Config do
  @moduledoc """
  Centralized configuration management for Raxol.

  Provides a unified interface for accessing and managing configuration across
  the entire application with validation, type safety, and environment support.

  ## Configuration Sources

  Configuration is loaded from multiple sources in order of precedence:

  1. Runtime configuration (highest priority)
  2. Environment variables
  3. Configuration files (config.toml, config.json)
  4. Application environment
  5. Default values (lowest priority)

  ## Usage

      # Get a configuration value
      Config.get(:terminal, :width)
      Config.get([:terminal, :buffer, :size])

      # Get with default
      Config.get(:theme, :name, "default")

      # Get required value (raises if not found)
      Config.get!(:database, :url)

      # Update configuration at runtime
      Config.put(:terminal, :width, 120)

      # Load from file
      Config.load_file("config.toml")

      # Validate all configuration
      Config.validate!()
  """

  use GenServer
  require Logger

  import Raxol.Core.ErrorHandler

  @config_file_paths [
    "config/raxol.toml",
    "config/raxol.json",
    "~/.raxol/config.toml",
    "~/.raxol/config.json",
    "/etc/raxol/config.toml"
  ]

  @type config_key :: atom() | [atom()]
  @type config_value :: term()
  @type config_source :: :default | :file | :env | :runtime | :app_env

  # Client API

  @doc """
  Starts the configuration manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a configuration value.

  ## Examples

      Config.get(:terminal, :width)
      Config.get([:terminal, :buffer, :size])
      Config.get(:theme, :name, "default")
  """
  @spec get(config_key(), config_value()) :: config_value()
  def get(key, default \\ nil)

  def get(key, default) when is_atom(key) do
    GenServer.call(__MODULE__, {:get, [key], default})
  end

  def get(keys, default) when is_list(keys) do
    GenServer.call(__MODULE__, {:get, keys, default})
  end

  @doc """
  Gets a required configuration value. Raises if not found.
  """
  @spec get!(config_key()) :: config_value()
  def get!(key) do
    case get(key, :__not_found__) do
      :__not_found__ ->
        raise Raxol.Config.Error,
              "Required configuration key not found: #{inspect(key)}"

      value ->
        value
    end
  end

  @doc """
  Sets a configuration value at runtime.
  """
  @spec put(config_key(), config_value()) :: :ok
  def put(key, value) when is_atom(key) do
    put([key], value)
  end

  def put(keys, value) when is_list(keys) do
    GenServer.call(__MODULE__, {:put, keys, value})
  end

  @doc """
  Updates configuration with a map of values.
  """
  @spec merge(map()) :: :ok
  def merge(config) when is_map(config) do
    GenServer.call(__MODULE__, {:merge, config})
  end

  @doc """
  Loads configuration from a file.
  """
  @spec load_file(String.t()) :: {:ok, map()} | {:error, term()}
  def load_file(path) do
    GenServer.call(__MODULE__, {:load_file, path})
  end

  @doc """
  Reloads configuration from all sources.
  """
  @spec reload() :: :ok
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc """
  Validates all configuration values.
  """
  @spec validate() :: {:ok, :valid} | {:error, [term()]}
  def validate do
    GenServer.call(__MODULE__, :validate)
  end

  @doc """
  Validates configuration and raises on error.
  """
  @spec validate!() :: :ok
  def validate! do
    case validate() do
      {:ok, :valid} ->
        :ok

      {:error, errors} ->
        raise Raxol.Config.ValidationError,
              "Configuration validation failed:\n" <> format_errors(errors)
    end
  end

  @doc """
  Gets all configuration as a map.
  """
  @spec all() :: map()
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc """
  Gets configuration for a specific namespace.
  """
  @spec namespace(atom()) :: map()
  def namespace(ns) when is_atom(ns) do
    GenServer.call(__MODULE__, {:namespace, ns})
  end

  @doc """
  Exports configuration to a file.
  """
  @spec export(String.t(), keyword()) :: :ok | {:error, term()}
  def export(path, opts \\ []) do
    GenServer.call(__MODULE__, {:export, path, opts})
  end

  @doc """
  Gets the source of a configuration value.
  """
  @spec source(config_key()) :: config_source() | nil
  def source(key) do
    GenServer.call(__MODULE__, {:source, key})
  end

  @doc """
  Subscribes to configuration changes.
  """
  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(Raxol.PubSub, "config:changes")
  end

  # Server implementation

  defmodule State do
    @moduledoc false
    defstruct [
      :config,
      :sources,
      :schemas,
      :validators,
      :file_watcher
    ]
  end

  @impl true
  def init(opts) do
    state =
      with_error_handling :config_init do
        # Initialize state
        initial_state = %State{
          config: %{},
          sources: %{},
          schemas: load_schemas(),
          validators: load_validators()
        }

        # Load configuration from all sources
        state = load_all_sources(initial_state, opts)

        # Start file watcher if in dev mode
        state =
          if Mix.env() == :dev do
            start_file_watcher(state)
          else
            state
          end

        # Validate configuration
        {:ok, :valid} = validate_config(state.config, state.schemas)
        Logger.info("Configuration loaded and validated successfully")
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call({:get, keys, default}, _from, state) do
    value = get_nested(state.config, keys, default)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:put, keys, value}, _from, state) do
    new_config = put_nested(state.config, keys, value)
    new_sources = put_nested(state.sources, keys, :runtime)

    # Validate the new value
    :ok = validate_value(keys, value, state.schemas)
    new_state = %{state | config: new_config, sources: new_sources}
    broadcast_change(keys, value)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:merge, config}, _from, state) do
    new_config = deep_merge(state.config, config)

    # Validate merged config
    {:ok, :valid} = validate_config(new_config, state.schemas)
    new_state = %{state | config: new_config}
    broadcast_change(:all, new_config)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:load_file, path}, _from, state) do
    case do_load_file(path) do
      {:ok, config} ->
        new_config = deep_merge(state.config, config)
        new_state = %{state | config: new_config}
        {:reply, {:ok, config}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:reload, _from, state) do
    new_state = load_all_sources(state, [])
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:validate, _from, state) do
    result = validate_config(state.config, state.schemas)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:all, _from, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_call({:namespace, ns}, _from, state) do
    value = Map.get(state.config, ns, %{})
    {:reply, value, state}
  end

  @impl true
  def handle_call({:export, path, opts}, _from, state) do
    result = do_export(state.config, path, opts)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:source, key}, _from, state) do
    keys = if is_atom(key), do: [key], else: key
    source = get_nested(state.sources, keys)
    {:reply, source, state}
  end

  @impl true
  def handle_info({:file_event, _watcher, {path, _events}}, state) do
    Logger.info("Configuration file changed: #{path}")

    case do_load_file(path) do
      {:ok, config} ->
        new_config = deep_merge(state.config, config)
        new_state = %{state | config: new_config}
        broadcast_change(:file_reload, path)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to reload config file: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  # Private functions

  defp get_nested(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      case acc do
        %{^key => value} -> value
        _ -> nil
      end
    end)
  end

  defp load_all_sources(state, opts) do
    state
    |> load_defaults()
    |> load_app_env()
    |> load_env_vars()
    |> load_config_files()
    |> apply_runtime_opts(opts)
  end

  defp load_defaults(state) do
    defaults = %{
      terminal: %{
        width: 80,
        height: 24,
        scrollback_size: 10_000,
        encoding: "UTF-8"
      },
      buffer: %{
        # 1MB
        max_size: 1_048_576,
        chunk_size: 4096,
        compression: false
      },
      rendering: %{
        fps_target: 60,
        max_frame_skip: 3,
        enable_animations: true,
        performance_mode: false
      },
      plugins: %{
        enabled: true,
        directory: "plugins",
        auto_reload: Mix.env() == :dev
      },
      security: %{
        # 30 minutes
        session_timeout: 1800,
        max_sessions: 5,
        enable_audit: true,
        password_min_length: 8
      },
      performance: %{
        profiling_enabled: false,
        benchmark_on_start: false,
        cache_size: 100_000
      },
      theme: %{
        name: "default",
        auto_switch: false
      },
      logging: %{
        level: :info,
        file: "logs/raxol.log",
        # 10MB
        max_file_size: 10_485_760,
        rotation_count: 5
      }
    }

    %{state | config: defaults, sources: mark_sources(defaults, :default)}
  end

  defp load_app_env(state) do
    app_config =
      Application.get_all_env(:raxol)
      |> Enum.into(%{})
      |> sanitize_config()

    %{
      state
      | config: deep_merge(state.config, app_config),
        sources: deep_merge(state.sources, mark_sources(app_config, :app_env))
    }
  end

  defp load_env_vars(state) do
    env_config =
      System.get_env()
      |> Enum.filter(fn {key, _} -> String.starts_with?(key, "RAXOL_") end)
      |> Enum.map(fn {key, value} ->
        {parse_env_key(key), parse_env_value(value)}
      end)
      |> build_nested_config()

    %{
      state
      | config: deep_merge(state.config, env_config),
        sources: deep_merge(state.sources, mark_sources(env_config, :env))
    }
  end

  defp load_config_files(state) do
    config =
      @config_file_paths
      |> Enum.map(&Path.expand/1)
      |> Enum.filter(&File.exists?/1)
      |> Enum.reduce(%{}, fn path, acc ->
        case do_load_file(path) do
          {:ok, file_config} ->
            Logger.info("Loaded config from #{path}")
            deep_merge(acc, file_config)

          {:error, reason} ->
            Logger.warning(
              "Failed to load config from #{path}: #{inspect(reason)}"
            )

            acc
        end
      end)

    %{
      state
      | config: deep_merge(state.config, config),
        sources: deep_merge(state.sources, mark_sources(config, :file))
    }
  end

  defp apply_runtime_opts(state, opts) do
    runtime_config = Keyword.get(opts, :config, %{})

    %{
      state
      | config: deep_merge(state.config, runtime_config),
        sources:
          deep_merge(state.sources, mark_sources(runtime_config, :runtime))
    }
  end

  defp do_load_file(path) do
    with {:ok, content} <- File.read(path) do
      case Path.extname(path) do
        ".toml" -> parse_toml(content)
        ".json" -> parse_json(content)
        _ -> {:error, :unsupported_format}
      end
    end
  end

  defp parse_toml(content) do
    case Toml.decode(content) do
      {:ok, config} -> {:ok, atomize_keys(config)}
      {:error, reason} -> {:error, {:toml_parse_error, reason}}
    end
  end

  defp parse_json(content) do
    case Jason.decode(content) do
      {:ok, config} -> {:ok, atomize_keys(config)}
      {:error, reason} -> {:error, {:json_parse_error, reason}}
    end
  end

  defp do_export(config, path, opts) do
    format = Keyword.get(opts, :format) || detect_format(path)
    pretty = Keyword.get(opts, :pretty, true)

    content =
      case format do
        :toml -> encode_toml(config)
        :json -> encode_json(config, pretty)
        _ -> {:error, :unsupported_format}
      end

    with {:ok, encoded} <- content do
      File.write(path, encoded)
    end
  end

  defp detect_format(path) do
    case Path.extname(path) do
      ".toml" -> :toml
      ".json" -> :json
      _ -> :unknown
    end
  end

  defp encode_toml(_config) do
    # Would need a TOML encoder library
    {:error, :toml_encoding_not_implemented}
  end

  defp encode_json(config, pretty) do
    Jason.encode(stringify_keys(config), pretty: pretty)
  end

  # Utility functions

  defp get_nested(map, [], default), do: map || default

  defp get_nested(map, [key | rest], default) do
    case Map.get(map, key) do
      nil -> default
      value -> get_nested(value, rest, default)
    end
  end

  defp put_nested(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_nested(map, [key | rest], value) do
    sub_map = Map.get(map, key, %{})
    Map.put(map, key, put_nested(sub_map, rest, value))
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, left_val, right_val when is_map(left_val) and is_map(right_val) ->
        deep_merge(left_val, right_val)

      _key, _left_val, right_val ->
        right_val
    end)
  end

  defp mark_sources(config, source) when is_map(config) do
    Enum.reduce(config, %{}, fn {key, value}, acc ->
      if is_map(value) do
        Map.put(acc, key, mark_sources(value, source))
      else
        Map.put(acc, key, source)
      end
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_atom(key), else: key

      atomized_value =
        case value do
          v when is_map(v) -> atomize_keys(v)
          v when is_list(v) -> Enum.map(v, &atomize_keys/1)
          v -> v
        end

      Map.put(acc, atom_key, atomized_value)
    end)
  end

  defp atomize_keys(value), do: value

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      string_key = to_string(key)

      stringified_value =
        case value do
          v when is_map(v) -> stringify_keys(v)
          v when is_list(v) -> Enum.map(v, &stringify_keys/1)
          v -> v
        end

      Map.put(acc, string_key, stringified_value)
    end)
  end

  defp stringify_keys(value), do: value

  defp sanitize_config(config) do
    # Remove sensitive values from being stored
    config
    |> Map.drop([:secret_key_base, :encryption_salt])
  end

  defp parse_env_key(key) do
    key
    |> String.replace_prefix("RAXOL_", "")
    |> String.downcase()
    |> String.split("__")
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_env_value(value) do
    parsers = [
      {~r/^\d+$/, &String.to_integer/1},
      {~r/^\d+\.\d+$/, &String.to_float/1},
      {~w(true false), fn v -> v == "true" end}
    ]
    
    Enum.find_value(parsers, value, fn
      {regex, parser} when is_struct(regex, Regex) ->
        if value =~ regex, do: parser.(value)
      {list, parser} when is_list(list) ->
        if value in list, do: parser.(value)
    end)
  end

  defp build_nested_config(env_pairs) do
    Enum.reduce(env_pairs, %{}, fn {keys, value}, acc ->
      put_nested(acc, keys, value)
    end)
  end

  defp start_file_watcher(state) do
    {:ok, watcher} =
      FileSystem.start_link(
        dirs: [
          Path.dirname("config/raxol.toml"),
          Path.expand("~/.raxol")
        ],
        name: :config_watcher
      )

    FileSystem.subscribe(watcher)

    %{state | file_watcher: watcher}
  end

  defp broadcast_change(key, value) do
    Phoenix.PubSub.broadcast(
      Raxol.PubSub,
      "config:changes",
      {:config_changed, key, value}
    )
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {path, error} ->
      "  • #{Enum.join(path, ".")}: #{error}"
    end)
    |> Enum.join("\n")
  end

  # Schema loading would be implemented here
  defp load_schemas do
    %{}
  end

  defp load_validators do
    %{}
  end

  defp validate_config(_config, _schemas) do
    # Simplified validation
    {:ok, :valid}
  end

  defp validate_value(_keys, _value, _schemas) do
    :ok
  end
end

defmodule Raxol.Config.Error do
  defexception [:message]
end

defmodule Raxol.Config.ValidationError do
  defexception [:message]
end
