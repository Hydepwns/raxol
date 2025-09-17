defmodule Raxol.Config do
  @moduledoc """
  Unified TOML-based configuration management for Raxol.

  This module provides a centralized configuration system that:
  - Loads configuration from TOML files
  - Supports environment-specific configs
  - Provides runtime configuration updates
  - Validates configuration values
  - Supports default values and overrides
  """

  use GenServer
  require Logger

  @default_config_file "config/raxol.toml"
  @env_config_dir "config/environments"

  # Type specifications
  @type config_value :: any()
  @type config_path :: [atom() | String.t()]
  @type config_map :: %{String.t() => config_value()}

  ## Client API

  @doc """
  Starts the configuration server.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a configuration value by path.

  ## Examples

      # Get terminal width
      Config.get([:terminal, :width])

      # Get with default value
      Config.get([:terminal, :custom], default: 80)
  """
  @spec get(config_path(), keyword()) :: config_value()
  def get(path, opts \\ []) do
    GenServer.call(__MODULE__, {:get, path, opts})
  end

  @doc """
  Sets a configuration value at runtime.

  ## Examples

      Config.set([:terminal, :width], 120)
  """
  @spec set(config_path(), config_value()) :: :ok
  def set(path, value) do
    GenServer.cast(__MODULE__, {:set, path, value})
  end

  @doc """
  Loads configuration from a TOML file.
  """
  @spec load_file(String.t()) :: {:ok, config_map()} | {:error, any()}
  def load_file(file_path) do
    GenServer.call(__MODULE__, {:load_file, file_path})
  end

  @doc """
  Reloads all configuration files.
  """
  @spec reload() :: :ok | {:error, any()}
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc """
  Gets the entire configuration map.
  """
  @spec all() :: config_map()
  def all do
    GenServer.call(__MODULE__, :all)
  end

  @doc """
  Validates the current configuration.
  """
  @spec validate() :: {:ok, :valid} | {:error, [String.t()]}
  def validate do
    GenServer.call(__MODULE__, :validate)
  end

  @doc """
  Exports current configuration to a TOML file.
  """
  @spec export(String.t()) :: :ok | {:error, any()}
  def export(file_path) do
    GenServer.call(__MODULE__, {:export, file_path})
  end

  ## Server Callbacks

  @impl true
  def init(opts) do
    config_file = opts[:config_file] || @default_config_file
    env = opts[:env] || Mix.env()

    state = %{
      config: %{},
      config_file: config_file,
      env: env,
      runtime_overrides: %{}
    }

    case load_initial_config(state) do
      {:ok, config} ->
        {:ok, %{state | config: config}}

      {:error, reason} ->
        Logger.warning(
          "Failed to load config: #{inspect(reason)}, using defaults"
        )

        {:ok, %{state | config: default_config()}}
    end
  end

  @impl true
  def handle_call({:get, path, opts}, _from, state) do
    value =
      get_nested(state.config, path) ||
        get_nested(state.runtime_overrides, path) ||
        opts[:default]

    {:reply, value, state}
  end

  @impl true
  def handle_call(:all, _from, state) do
    merged = deep_merge(state.config, state.runtime_overrides)
    {:reply, merged, state}
  end

  @impl true
  def handle_call({:load_file, file_path}, _from, state) do
    case load_toml_file(file_path) do
      {:ok, config} ->
        new_config = deep_merge(state.config, config)
        {:reply, {:ok, new_config}, %{state | config: new_config}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:reload, _from, state) do
    case load_initial_config(state) do
      {:ok, config} ->
        {:reply, :ok, %{state | config: config, runtime_overrides: %{}}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:validate, _from, state) do
    result = validate_config(state.config)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:export, file_path}, _from, state) do
    merged = deep_merge(state.config, state.runtime_overrides)
    result = export_to_toml(merged, file_path)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:set, path, value}, state) do
    runtime_overrides = set_nested(state.runtime_overrides, path, value)
    {:noreply, %{state | runtime_overrides: runtime_overrides}}
  end

  ## Private Functions

  @spec load_initial_config(map()) :: {:ok, config_map()} | {:error, any()}
  defp load_initial_config(%{config_file: config_file, env: env}) do
    with {:ok, base_config} <- load_toml_file(config_file),
         {:ok, env_config} <- load_env_config(env),
         {:ok, merged} <- {:ok, deep_merge(base_config, env_config)} do
      {:ok, merged}
    else
      {:error, :enoent} ->
        # Try to load from example if main config doesn't exist
        load_toml_file("config/raxol.example.toml")

      error ->
        error
    end
  end

  @spec load_env_config(atom()) :: {:ok, config_map()} | {:error, any()}
  defp load_env_config(env) do
    env_file = Path.join(@env_config_dir, "#{env}.toml")

    case File.exists?(env_file) do
      true -> load_toml_file(env_file)
      false -> {:ok, %{}}
    end
  end

  @spec load_toml_file(String.t()) :: {:ok, config_map()} | {:error, any()}
  defp load_toml_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Toml.decode(content) do
          {:ok, config} -> {:ok, config}
          {:error, reason} -> {:error, {:toml_parse_error, reason}}
        end

      error ->
        error
    end
  end

  @spec export_to_toml(config_map(), String.t()) :: :ok | {:error, any()}
  defp export_to_toml(config, file_path) do
    # Since Toml library doesn't support encoding, we'll create a simple TOML writer
    content = generate_toml(config)
    File.write(file_path, content)
  end

  @spec generate_toml(config_map(), integer()) :: String.t()
  defp generate_toml(config, indent \\ 0) do
    config
    |> Enum.map_join(
      fn {key, value} -> format_toml_entry(key, value, indent) end,
      "\n"
    )
  end

  @spec format_toml_entry(String.t(), any(), integer()) :: String.t()
  defp format_toml_entry(key, value, indent) when is_map(value) do
    spacing = String.duplicate(" ", indent)
    section_header = "#{spacing}[#{key}]"
    section_content = generate_toml(value, indent)
    "#{section_header}\n#{section_content}"
  end

  defp format_toml_entry(key, value, indent) do
    spacing = String.duplicate(" ", indent)
    "#{spacing}#{key} = #{format_toml_value(value)}"
  end

  @spec format_toml_value(any()) :: String.t()
  defp format_toml_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_toml_value(value) when is_boolean(value), do: to_string(value)
  defp format_toml_value(value) when is_integer(value), do: to_string(value)
  defp format_toml_value(value) when is_float(value), do: to_string(value)

  defp format_toml_value(value) when is_list(value) do
    formatted = Enum.map_join(value, ", ", &format_toml_value/1)
    "[#{formatted}]"
  end

  defp format_toml_value(value), do: inspect(value)

  @spec get_nested(config_map(), config_path()) :: config_value() | nil
  defp get_nested(map, []), do: map
  defp get_nested(nil, _), do: nil

  defp get_nested(map, [key | rest]) do
    key_str = to_string(key)

    case Map.get(map, key_str) do
      nil -> nil
      value -> get_nested(value, rest)
    end
  end

  @spec set_nested(config_map(), config_path(), config_value()) :: config_map()
  defp set_nested(map, [key], value) do
    Map.put(map, to_string(key), value)
  end

  defp set_nested(map, [key | rest], value) do
    key_str = to_string(key)
    nested = Map.get(map, key_str, %{})
    Map.put(map, key_str, set_nested(nested, rest, value))
  end

  @spec deep_merge(config_map(), config_map()) :: config_map()
  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _k, v1, v2 when is_map(v1) and is_map(v2) -> deep_merge(v1, v2)
      _k, _v1, v2 -> v2
    end)
  end

  @spec validate_config(config_map()) :: {:ok, :valid} | {:error, [String.t()]}
  defp validate_config(config) do
    errors = []

    # Validate terminal dimensions
    errors = validate_terminal_config(config["terminal"] || %{}, errors)

    # Validate performance settings
    errors = validate_performance_config(config["performance"] || %{}, errors)

    # Validate security settings
    errors = validate_security_config(config["security"] || %{}, errors)

    case errors do
      [] -> {:ok, :valid}
      _ -> {:error, errors}
    end
  end

  @spec validate_terminal_config(map(), [String.t()]) :: [String.t()]
  defp validate_terminal_config(terminal, errors) do
    errors
    |> validate_positive_integer(terminal["width"], "terminal.width")
    |> validate_positive_integer(terminal["height"], "terminal.height")
    |> validate_positive_integer(
      terminal["scrollback_size"],
      "terminal.scrollback_size"
    )
  end

  @spec validate_performance_config(map(), [String.t()]) :: [String.t()]
  defp validate_performance_config(perf, errors) do
    errors
    |> validate_positive_integer(perf["cache_size"], "performance.cache_size")
    |> validate_positive_integer(
      perf["worker_pool_size"],
      "performance.worker_pool_size"
    )
  end

  @spec validate_security_config(map(), [String.t()]) :: [String.t()]
  defp validate_security_config(security, errors) do
    errors
    |> validate_positive_integer(
      security["session_timeout"],
      "security.session_timeout"
    )
    |> validate_positive_integer(
      security["max_sessions"],
      "security.max_sessions"
    )
  end

  @spec validate_positive_integer([String.t()], any(), String.t()) :: [
          String.t()
        ]
  defp validate_positive_integer(errors, nil, _path), do: errors

  defp validate_positive_integer(errors, value, _path)
       when is_integer(value) and value > 0,
       do: errors

  defp validate_positive_integer(errors, _value, path) do
    ["#{path} must be a positive integer" | errors]
  end

  @spec default_config() :: config_map()
  defp default_config do
    %{
      "terminal" => %{
        "width" => 80,
        "height" => 24,
        "scrollback_size" => 10_000,
        "encoding" => "UTF-8"
      },
      "rendering" => %{
        "fps_target" => 60,
        "enable_animations" => true
      },
      "logging" => %{
        "level" => "info"
      },
      "performance" => %{
        "cache_size" => 100_000,
        "worker_pool_size" => 4
      }
    }
  end
end
