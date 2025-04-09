defmodule Raxol.Cloud.Config do
  @moduledoc """
  Configuration management for Raxol cloud integrations.

  Provides centralized configuration management with validation,
  dynamic updates, and multiple source support.
  """

  alias Raxol.Cloud.{Core, StateManager}

  # Process dictionary key for configuration state
  @state_key :cloud_config

  # Default configuration values
  @defaults %{
    edge: %{
      mode: :auto,
      sync_interval: 60000,
      connection_check_interval: 30000,
      retry_limit: 3,
      compression: true,
      offline_cache_size: 104857600 # 100MB
    },
    monitoring: %{
      active: true,
      metrics_interval: 10000,
      health_check_interval: 60000,
      error_sample_rate: 1.0,
      metrics_batch_size: 100,
      backends: [],
      alert_thresholds: %{
        error_rate: 0.05,
        response_time: 1000,
        memory_usage: 0.9
      }
    },
    providers: %{
      aws: %{enabled: false, region: "us-west-2"},
      azure: %{enabled: false, region: "westus2"},
      gcp: %{enabled: false, region: "us-central1"}
    },
    services: %{
      discovery: %{
        enabled: false,
        provider: :custom,
        register_on_startup: true
      },
      deployment: %{
        enabled: false,
        strategy: :rolling,
        auto_scaling: true,
        min_instances: 1,
        max_instances: 10
      }
    }
  }

  @doc """
  Initializes the configuration system.

  ## Options

  * `:sources` - List of configuration sources [:env, :file]
  * `:environment` - Environment to use (:development, :test, :production)
  * `:config_file` - Path to configuration file
  * `:auto_apply` - Whether to automatically apply configuration
  """
  def init(opts \\ []) do
    state = %{
      config: %{},
      sources: Keyword.get(opts, :sources, [:env, :file]),
      environment: Keyword.get(opts, :environment, :development),
      last_updated: nil,
      validation_errors: []
    }

    # Load configuration from sources
    {config, errors} = load_from_sources(state.sources, opts)

    # Update state
    state = %{state |
      config: config,
      validation_errors: errors,
      last_updated: DateTime.utc_now()
    }

    # Store state
    StateManager.put(@state_key, state)

    # Apply configuration if requested
    if Keyword.get(opts, :auto_apply, true) and Enum.empty?(errors) do
      apply_configuration(config)
    end

    if Enum.empty?(errors) do
      {:ok, %{status: :initialized, sources: state.sources}}
    else
      {:error, %{status: :initialized_with_errors, errors: errors}}
    end
  end

  @doc """
  Gets the current configuration.

  ## Options

  * `:section` - Specific configuration section to get
  * `:flatten` - Whether to flatten nested maps
  """
  def get(opts \\ []) do
    state = get_state()
    section = Keyword.get(opts, :section)
    flatten = Keyword.get(opts, :flatten, false)

    config = if section do
      Map.get(state.config, section, Map.get(@defaults, section, %{}))
    else
      state.config
    end

    if flatten do
      flatten_map(config)
    else
      config
    end
  end

  @doc """
  Updates the configuration with new values.

  ## Options

  * `:section` - Section to update
  * `:validate` - Whether to validate the configuration
  * `:persist` - Whether to persist changes
  * `:apply` - Whether to apply changes
  """
  def update(new_config, opts \\ []) do
    state = get_state()
    section = Keyword.get(opts, :section)

    # Update configuration
    updated_config = if section do
      Map.update(state.config, section, new_config, &Map.merge(&1, new_config))
    else
      deep_merge(state.config, new_config)
    end

    # Validate if requested
    {valid, errors} = if Keyword.get(opts, :validate, true) do
      validate_config(updated_config)
    else
      {true, []}
    end

    if valid do
      # Update state
      updated_state = %{state |
        config: updated_config,
        last_updated: DateTime.utc_now(),
        validation_errors: []
      }
      StateManager.put(@state_key, updated_state)

      # Persist if requested
      if Keyword.get(opts, :persist, false) do
        persist_config(updated_config)
      end

      # Apply if requested
      if Keyword.get(opts, :apply, true) do
        apply_configuration(updated_config)
      end

      {:ok, %{status: :updated}}
    else
      {:error, %{status: :validation_failed, errors: errors}}
    end
  end

  @doc """
  Reloads configuration from all sources.

  ## Options

  * `:sources` - List of sources to reload from
  * `:apply` - Whether to apply the reloaded configuration
  """
  def reload(opts \\ []) do
    state = get_state()
    sources = Keyword.get(opts, :sources, state.sources)

    # Load configuration from sources
    {config, errors} = load_from_sources(sources, opts)

    if Enum.empty?(errors) do
      # Update state
      updated_state = %{state |
        config: config,
        last_updated: DateTime.utc_now(),
        validation_errors: []
      }
      StateManager.put(@state_key, updated_state)

      # Apply if requested
      if Keyword.get(opts, :apply, true) do
        apply_configuration(config)
      end

      {:ok, %{status: :reloaded, sources: sources}}
    else
      {:error, %{status: :reload_failed, errors: errors}}
    end
  end

  @doc """
  Gets the current status of the configuration system.
  """
  def status do
    state = get_state()

    %{
      environment: state.environment,
      last_updated: state.last_updated,
      sources: state.sources,
      validation_errors: state.validation_errors
    }
  end

  @doc """
  Gets the default configuration value for a key.
  """
  def get_default(key) when is_binary(key) do
    keys = String.split(key, ".")
    get_in(@defaults, Enum.map(keys, &String.to_atom/1))
  end

  def get_default(key) when is_atom(key) do
    Map.get(@defaults, key)
  end

  # Private functions

  defp get_state do
    StateManager.get(@state_key) || %{
      config: %{},
      sources: [:env, :file],
      environment: :development,
      last_updated: nil,
      validation_errors: []
    }
  end

  defp load_from_sources(sources, opts) do
    # Start with empty configuration
    config = %{}

    # Load from each source
    {config, errors} = Enum.reduce(sources, {config, []}, fn source, {acc_config, acc_errors} ->
      case load_from_source(source, opts) do
        {:ok, source_config} -> {deep_merge(acc_config, source_config), acc_errors}
        {:error, error} -> {acc_config, [error | acc_errors]}
      end
    end)

    # Validate final configuration
    {valid, validation_errors} = validate_config(config)

    if valid do
      {config, errors}
    else
      {config, errors ++ validation_errors}
    end
  end

  defp load_from_source(:env, _opts) do
    # Load configuration from environment variables
    config = System.get_env()
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, "RAXOL_CLOUD_") end)
    |> Enum.map(fn {key, value} ->
      # Convert key from RAXOL_CLOUD_EDGE_MODE to edge.mode
      key = key
      |> String.replace_prefix("RAXOL_CLOUD_", "")
      |> String.downcase()
      |> String.replace("_", ".")

      # Convert value to appropriate type
      {key, convert_env_value(key, value)}
    end)
    |> Enum.into(%{})

    # Convert flat map to nested map
    config = unflatten_map(config)

    {:ok, config}
  end

  defp load_from_source(:file, opts) do
    # Load configuration from file
    config_file = Keyword.get(opts, :config_file, "config/cloud.json")

    if File.exists?(config_file) do
      case File.read(config_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, config} -> {:ok, atomize_keys(config)}
            {:error, reason} -> {:error, {:file_parse_error, config_file, reason}}
          end

        {:error, reason} ->
          {:error, {:file_read_error, config_file, reason}}
      end
    else
      {:error, {:file_not_found, config_file}}
    end
  end

  defp validate_config(config) do
    errors = []

    # Check for invalid keys
    unknown_keys = Map.keys(config) -- Map.keys(@defaults)
    errors = if Enum.empty?(unknown_keys) do
      errors
    else
      [{:unknown_keys, unknown_keys} | errors]
    end

    # Basic type validation for common fields
    errors = if is_map(config[:edge]) and not is_atom(Map.get(config[:edge], :mode)) do
      [{:invalid_type, [:edge, :mode], :atom, Map.get(config[:edge], :mode)} | errors]
    else
      errors
    end

    errors = if is_map(config[:monitoring]) and not is_boolean(Map.get(config[:monitoring], :active)) do
      [{:invalid_type, [:monitoring, :active], :boolean, Map.get(config[:monitoring], :active)} | errors]
    else
      errors
    end

    {Enum.empty?(errors), Enum.reverse(errors)} # Reverse to maintain original order if needed
  end

  defp apply_configuration(config) do
    # Extract component configurations
    edge_config = Map.get(config, :edge, %{})
    monitoring_config = Map.get(config, :monitoring, %{})
    providers = Map.get(config, :providers, %{})
    |> Enum.filter(fn {_provider, config} -> Map.get(config, :enabled, false) end)
    |> Enum.map(fn {provider, _} -> provider end)

    # Convert to keyword lists
    edge_opts = map_to_keyword(edge_config)
    monitoring_opts = map_to_keyword(monitoring_config)

    # Initialize Core with new configuration
    _ = Core.init(
      edge: edge_opts,
      monitoring: monitoring_opts,
      providers: providers
    )

    :ok
  end

  defp persist_config(_config) do
    # Would write to a file - simplified version just returns :ok
    :ok
  end

  defp convert_env_value(key, value) do
    # Simple type conversion based on key pattern
    cond do
      String.ends_with?(key, "interval") or String.ends_with?(key, "timeout") or String.ends_with?(key, "limit") ->
        String.to_integer(value)

      String.ends_with?(key, "rate") or String.ends_with?(key, "ratio") ->
        String.to_float(value)

      value in ["true", "false"] ->
        value == "true"

      String.ends_with?(key, "mode") or String.ends_with?(key, "strategy") ->
        String.to_atom(value)

      true ->
        value
    end
  end

  defp flatten_map(map, prefix \\ "") do
    Enum.flat_map(map, fn {key, value} ->
      key_string = if prefix == "", do: to_string(key), else: "#{prefix}.#{key}"

      if is_map(value) and not is_struct(value) do
        flatten_map(value, key_string)
      else
        [{key_string, value}]
      end
    end)
    |> Enum.into(%{})
  end

  defp unflatten_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      keys = String.split(key, ".")
      put_in_path(acc, keys, value)
    end)
  end

  defp put_in_path(map, [key], value) do
    key = if key =~ ~r/^\d+$/, do: String.to_integer(key), else: String.to_atom(key)
    Map.put(map, key, value)
  end

  defp put_in_path(map, [key | rest], value) do
    key = if key =~ ~r/^\d+$/, do: String.to_integer(key), else: String.to_atom(key)

    Map.update(map, key, put_in_path(%{}, rest, value), fn existing ->
      put_in_path(existing, rest, value)
    end)
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      if is_map(left_value) and is_map(right_value) do
        deep_merge(left_value, right_value)
      else
        right_value
      end
    end)
  end

  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {String.to_atom(k), atomize_keys(v)} end)
    |> Enum.into(%{})
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  defp map_to_keyword(map) do
    map |> Enum.map(fn {k, v} -> {k, v} end)
  end
end
