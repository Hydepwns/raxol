defmodule Raxol.Plugins.PluginConfig do
  import Raxol.Guards

  @moduledoc """
  Handles persistence of plugin configurations.
  Stores and loads plugin configurations from disk.
  """

  @derive Jason.Encoder
  @config_dir ".config/raxol/plugins"
  @config_file "plugin_config.json"

  @type t :: %__MODULE__{
          plugin_configs: %{String.t() => map()},
          enabled_plugins: [String.t()]
        }

  defstruct [
    :plugin_configs,
    :enabled_plugins
  ]

  @doc """
  Creates a new plugin configuration manager.
  """
  def new do
    %__MODULE__{
      plugin_configs: %{},
      enabled_plugins: []
    }
  end

  @doc """
  Loads plugin configurations from disk.
  """
  def load do
    config_path = config_file_path()

    case File.read(config_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, decoded} ->
            # Convert string keys to atom keys to match struct field names
            decoded_with_atom_keys =
              for {key, value} <- decoded, into: %{} do
                {String.to_atom(key), value}
              end

            # Merge with defaults to ensure all fields are present
            defaults = Map.from_struct(new())
            merged = Map.merge(defaults, decoded_with_atom_keys)
            config = struct(__MODULE__, merged)
            {:ok, config}

          {:error, reason} ->
            {:error, "Failed to decode plugin configuration: #{reason}"}
        end

      {:error, :enoent} ->
        # Config file doesn't exist, return default config
        {:ok, new()}

      {:error, reason} ->
        {:error, "Failed to read plugin configuration: #{reason}"}
    end
  end

  @doc """
  Saves plugin configurations to disk.
  """
  def save(%__MODULE__{} = config) do
    config_path = config_file_path()
    config_dir = Path.dirname(config_path)

    # Ensure config directory exists
    File.mkdir_p!(config_dir)

    case Jason.encode(config) do
      {:ok, encoded} ->
        case File.write(config_path, encoded) do
          :ok ->
            {:ok, config}

          {:error, reason} ->
            {:error, "Failed to write plugin configuration: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to encode plugin configuration: #{reason}"}
    end
  end

  @doc """
  Gets the configuration for a specific plugin.
  """
  def get_plugin_config(%__MODULE__{} = config, plugin_name)
      when binary?(plugin_name) do
    Map.get(config.plugin_configs, plugin_name, %{})
  end

  @doc """
  Updates the configuration for a specific plugin.
  """
  def update_plugin_config(%__MODULE__{} = config, plugin_name, plugin_config)
      when binary?(plugin_name) and map?(plugin_config) do
    updated_configs = Map.put(config.plugin_configs, plugin_name, plugin_config)
    %{config | plugin_configs: updated_configs}
  end

  @doc """
  Checks if a plugin is enabled.
  """
  def plugin_enabled?(%__MODULE__{} = config, plugin_name)
      when binary?(plugin_name) do
    plugin_name in config.enabled_plugins
  end

  @doc """
  Enables a plugin.
  """
  def enable_plugin(%__MODULE__{} = config, plugin_name)
      when binary?(plugin_name) do
    if plugin_name in config.enabled_plugins do
      config
    else
      %{config | enabled_plugins: [plugin_name | config.enabled_plugins]}
    end
  end

  @doc """
  Disables a plugin.
  """
  def disable_plugin(%__MODULE__{} = config, plugin_name)
      when binary?(plugin_name) do
    %{
      config
      | enabled_plugins: List.delete(config.enabled_plugins, plugin_name)
    }
  end

  # Private functions

  defp config_file_path do
    Path.join([System.get_env("HOME"), @config_dir, @config_file])
  end
end
