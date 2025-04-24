defmodule Raxol.Terminal.Config.Persistence do
  @moduledoc """
  Handles loading and saving terminal configuration.

  Provides functions for persisting configuration to disk and loading it back.
  """

  alias Raxol.Terminal.Config.{Schema, Validation}

  @default_config_path "priv/config/terminal.json"

  @doc """
  Loads terminal configuration from the default path.

  If the configuration file doesn't exist, returns the default configuration.

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  def load_config do
    load_config(@default_config_path)
  end

  @doc """
  Loads terminal configuration from the specified path.

  If the configuration file doesn't exist, returns the default configuration.

  ## Parameters

  * `path` - The file path to load from

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  def load_config(path) do
    case File.read(path) do
      {:ok, contents} ->
        parse_config(contents)

      {:error, :enoent} ->
        # File doesn't exist, return default config
        {:ok, Schema.default_config()}

      {:error, reason} ->
        {:error, "Failed to read config file: #{inspect(reason)}"}
    end
  end

  @doc """
  Parses configuration from JSON string.

  ## Parameters

  * `json` - The JSON string to parse

  ## Returns

  `{:ok, config}` or `{:error, reason}`
  """
  def parse_config(json) do
    case Jason.decode(json) do
      {:ok, config} ->
        # Convert string keys to atoms (safely)
        atomized_config = atomize_keys(config)
        # Validate the config against the schema
        Validation.validate_config(atomized_config)

      {:error, reason} ->
        {:error, "Failed to parse config: #{inspect(reason)}"}
    end
  end

  @doc """
  Saves terminal configuration to the default path.

  ## Parameters

  * `config` - The configuration to save

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def save_config(config) do
    save_config(config, @default_config_path)
  end

  @doc """
  Saves terminal configuration to the specified path.

  ## Parameters

  * `config` - The configuration to save
  * `path` - The file path to save to

  ## Returns

  `:ok` or `{:error, reason}`
  """
  def save_config(config, path) do
    # Ensure the directory exists
    dirname = Path.dirname(path)
    File.mkdir_p(dirname)

    # Validate the config before saving
    case Validation.validate_config(config) do
      {:ok, validated_config} ->
        # Convert to JSON
        case Jason.encode(validated_config, pretty: true) do
          {:ok, json} ->
            # Write to file
            File.write(path, json)

          {:error, reason} ->
            {:error, "Failed to encode config: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Recursively convert string keys in a map to atoms
  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {
        (if is_binary(k), do: String.to_atom(k), else: k),
        atomize_keys(v)
      }
    end)
    |> Enum.into(%{})
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value
end
