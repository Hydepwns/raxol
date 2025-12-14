defmodule Raxol.Core.Config do
  @moduledoc """
  Pure functional configuration management for Raxol.

  This module provides purely functional operations on configuration data.
  All functions take config as input and return new config as output - no processes,
  no side effects except where explicitly documented.

  ## Design

  Following Rich Hickey's principle: "State is not a service."

  Configuration is just data - maps with namespaced sections. There's no need
  to serialize read operations through a GenServer mailbox when the data is
  immutable between updates.

  ## Usage

      # Create default config
      config = Config.new()

      # Get/set values
      width = Config.get(config, :terminal, :width)
      config = Config.put(config, :terminal, :width, 120)

      # Merge configs (file load, runtime override)
      config = Config.merge(config, loaded_config)

      # Get entire namespace
      terminal_config = Config.get_namespace(config, :terminal)

  ## Runtime Storage

  For runtime access, use `Raxol.Core.Config.Store` which backs this data
  with ETS for fast concurrent reads. This module is the pure functional core.
  """

  @type namespace ::
          :terminal | :plugins | :performance | :security | :ui | :benchmark
  @type key :: atom()
  @type value :: any()
  @type t :: %{
          version: String.t(),
          terminal: map(),
          plugins: map(),
          performance: map(),
          security: map(),
          ui: map(),
          benchmark: map()
        }

  # ============================================================================
  # Constructors
  # ============================================================================

  @doc """
  Creates a new config with default values for all namespaces.

  ## Examples

      config = Config.new()
      config.terminal.width  # => 80
  """
  @spec new() :: t()
  def new do
    %{
      version: "1.5.4",
      terminal: default_terminal(),
      plugins: default_plugins(),
      performance: default_performance(),
      security: default_security(),
      ui: default_ui(),
      benchmark: default_benchmark()
    }
  end

  @doc """
  Creates a config from a map, filling in defaults for missing keys.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    new()
    |> merge(atomize_keys(map))
  end

  # ============================================================================
  # Accessors
  # ============================================================================

  @doc """
  Gets a value from config at namespace/key path.

  Returns default if namespace or key doesn't exist.

  ## Examples

      Config.get(config, :terminal, :width)
      Config.get(config, :terminal, :missing, 0)
  """
  @spec get(t(), namespace(), key(), value()) :: value()
  def get(config, namespace, key, default \\ nil) do
    config
    |> Map.get(namespace, %{})
    |> Map.get(key, default)
  end

  @doc """
  Gets an entire namespace from config.

  ## Examples

      terminal = Config.get_namespace(config, :terminal)
      # => %{width: 80, height: 24, ...}
  """
  @spec get_namespace(t(), namespace()) :: map()
  def get_namespace(config, namespace) do
    Map.get(config, namespace, %{})
  end

  # ============================================================================
  # Transformers
  # ============================================================================

  @doc """
  Puts a value into config at namespace/key path.

  Returns new config (original is unchanged).

  ## Examples

      config = Config.put(config, :terminal, :width, 120)
  """
  @spec put(t(), namespace(), key(), value()) :: t()
  def put(config, namespace, key, value) do
    namespace_config =
      config
      |> Map.get(namespace, %{})
      |> Map.put(key, value)

    Map.put(config, namespace, namespace_config)
  end

  @doc """
  Puts an entire namespace into config.

  ## Examples

      config = Config.put_namespace(config, :terminal, %{width: 120, height: 40})
  """
  @spec put_namespace(t(), namespace(), map()) :: t()
  def put_namespace(config, namespace, namespace_config)
      when is_map(namespace_config) do
    Map.put(config, namespace, namespace_config)
  end

  @doc """
  Resets a namespace to its default values.

  ## Examples

      config = Config.reset_namespace(config, :terminal)
  """
  @spec reset_namespace(t(), namespace()) :: t()
  def reset_namespace(config, namespace) do
    Map.put(config, namespace, default_for(namespace))
  end

  @doc """
  Deep merges override config into base config.

  Override values take precedence. Nested maps are merged recursively.

  ## Examples

      base = Config.new()
      override = %{terminal: %{width: 120}}
      config = Config.merge(base, override)
      # config.terminal.width => 120
      # config.terminal.height => 24 (preserved from base)
  """
  @spec merge(t(), map()) :: t()
  def merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn
      _key, base_val, override_val
      when is_map(base_val) and is_map(override_val) ->
        Map.merge(base_val, override_val)

      _key, _base_val, override_val ->
        override_val
    end)
  end

  # ============================================================================
  # Validation
  # ============================================================================

  @doc """
  Validates config value for a given namespace and key.

  Returns `:ok` or `{:error, reason}`.

  ## Examples

      Config.validate_value(:terminal, :width, 80)   # => :ok
      Config.validate_value(:terminal, :width, -1)   # => {:error, "width must be positive"}
  """
  @spec validate_value(namespace(), key(), value()) ::
          :ok | {:error, String.t()}
  def validate_value(:terminal, :width, value)
      when is_integer(value) and value > 0,
      do: :ok

  def validate_value(:terminal, :width, _),
    do: {:error, "width must be a positive integer"}

  def validate_value(:terminal, :height, value)
      when is_integer(value) and value > 0,
      do: :ok

  def validate_value(:terminal, :height, _),
    do: {:error, "height must be a positive integer"}

  def validate_value(:performance, :memory_limit_mb, value)
      when is_integer(value) and value > 0,
      do: :ok

  def validate_value(:performance, :memory_limit_mb, _),
    do: {:error, "memory_limit_mb must be a positive integer"}

  def validate_value(_namespace, _key, _value), do: :ok

  @doc """
  Validates entire namespace config.

  Returns `:ok` or `{:error, [errors]}`.
  """
  @spec validate_namespace(namespace(), map()) :: :ok | {:error, [String.t()]}
  def validate_namespace(namespace, config) when is_map(config) do
    errors =
      config
      |> Enum.map(fn {key, value} -> validate_value(namespace, key, value) end)
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, msg} -> msg end)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  # ============================================================================
  # Serialization
  # ============================================================================

  @doc """
  Encodes config to JSON string.

  ## Examples

      {:ok, json} = Config.to_json(config)
  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, any()}
  def to_json(config) do
    Jason.encode(config, pretty: true)
  end

  @doc """
  Decodes JSON string to config.

  ## Examples

      {:ok, config} = Config.from_json(json_string)
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, any()}
  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> {:ok, from_map(decoded)}
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Defaults
  # ============================================================================

  @doc false
  def default_for(:terminal), do: default_terminal()
  def default_for(:plugins), do: default_plugins()
  def default_for(:performance), do: default_performance()
  def default_for(:security), do: default_security()
  def default_for(:ui), do: default_ui()
  def default_for(:benchmark), do: default_benchmark()
  def default_for(_), do: %{}

  defp default_terminal do
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

  defp default_plugins do
    %{
      enabled_plugins: [],
      plugin_configs: %{},
      auto_load: true,
      search_paths: ["~/.raxol/plugins", "./plugins"]
    }
  end

  defp default_performance do
    %{
      parser_cache_size: 1000,
      render_cache_enabled: true,
      memory_limit_mb: 100,
      gc_threshold: 0.8
    }
  end

  defp default_security do
    %{
      encryption_enabled: false,
      key_rotation_hours: 24,
      audit_logging: true,
      max_session_duration: 86_400
    }
  end

  defp default_ui do
    %{
      theme: "default",
      animations_enabled: true,
      transition_duration: 200,
      component_cache_size: 100
    }
  end

  defp default_benchmark do
    %{
      warmup_time: 1000,
      measurement_time: 5000,
      memory_time: 2000,
      parallel_jobs: 1
    }
  end

  # ============================================================================
  # Utilities
  # ============================================================================

  # Known config keys that are safe to atomize
  @known_keys ~w(
    version terminal plugins performance security ui benchmark
    width height colors foreground background cursor input
    mouse_enabled paste_mode render_fps buffer_size
    enabled_plugins plugin_configs auto_load search_paths
    parser_cache_size render_cache_enabled memory_limit_mb gc_threshold
    encryption_enabled key_rotation_hours audit_logging max_session_duration
    theme animations_enabled transition_duration component_cache_size
    warmup_time measurement_time memory_time parallel_jobs
  )a

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      atom_key = safe_to_atom(key)
      {atom_key, atomize_keys(value)}
    end)
  end

  defp atomize_keys(list) when is_list(list),
    do: Enum.map(list, &atomize_keys/1)

  defp atomize_keys(value), do: value

  defp safe_to_atom(key) when is_atom(key), do: key

  defp safe_to_atom(key) when is_binary(key) do
    atom = String.to_atom(key)

    if atom in @known_keys do
      atom
    else
      # Keep as string if not a known key (safety measure)
      key
    end
  end
end
